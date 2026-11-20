from types import SimpleNamespace
import pytest
from app.main import app
from app.content.router import ContentStore, get_content_store


def test_delete_post_rejects_other_author_before_recursive_cleanup():
    deleted = []
    class Reference:
        def document(self, post): return self
        def get(self): return SimpleNamespace(exists=True, to_dict=lambda: {'userId': 'owner'})
    class Database:
        def collection(self, name): return Reference()
        def recursive_delete(self, reference): deleted.append(reference)
    store = ContentStore()
    store.database = lambda: Database()
    with pytest.raises(PermissionError): store.delete_post('other', 'post')
    assert deleted == []
    store.delete_post('owner', 'post')
    assert len(deleted) == 1


def test_deletion_routes_use_verified_uid_not_client_supplied_owner(client, firebase_identity):
    calls = []
    class Store:
        def delete_post(self, uid, item): calls.append(('post', uid, item))
        def delete_journal(self, uid, item): calls.append(('journal', uid, item))
    app.dependency_overrides[get_content_store] = lambda: Store()
    firebase_identity.valid_tokens['good'] = 'owner'
    headers = {'Authorization': 'Bearer good'}
    assert client.delete('/community/posts/post-1', headers=headers).status_code == 204
    assert client.delete('/journal/entries/entry-1', headers=headers).status_code == 204
    assert calls == [('post', 'owner', 'post-1'), ('journal', 'owner', 'entry-1')]
    assert client.delete('/community/posts/post-1').status_code == 401


def test_non_owner_gets_forbidden(client, firebase_identity):
    class Store:
        def delete_post(self, uid, post): raise PermissionError()
    app.dependency_overrides[get_content_store] = lambda: Store()
    firebase_identity.valid_tokens['good'] = 'other'
    assert client.delete('/community/posts/post-1', headers={'Authorization': 'Bearer good'}).status_code == 403


@pytest.mark.parametrize('remaining,expected', [([], None),
    ([{'entryDate': '2026-10-01T00:00:00', 'relapseFlag': True}, {'entryDate': '2026-11-10T00:00:00', 'relapseFlag': True}], '2026-11-10T00:00:00')])
def test_deleting_relapse_updates_streak_anchor_and_deletes_in_one_transaction(monkeypatch, remaining, expected):
    from firebase_admin import firestore
    writes = []
    class Transaction:
        def update(self, reference, value): writes.append(('update', value))
        def delete(self, reference): writes.append(('delete', reference.path))
    class Reference:
        def __init__(self, path=()): self.path = path
        def collection(self, name): return Reference((*self.path, name))
        def document(self, name): return Reference((*self.path, name))
        def get(self, **kwargs):
            return SimpleNamespace(exists=True, to_dict=lambda: {'relapseFlag': True})
        def stream(self, **kwargs):
            return [SimpleNamespace(id=str(i), to_dict=lambda row=row: row) for i, row in enumerate(remaining)]
    class Database(Reference):
        def transaction(self): return Transaction()
    monkeypatch.setattr(firestore, 'transactional', lambda fn: fn)
    store = ContentStore()
    store.database = lambda: Database()
    store.delete_journal('owner', 'target')
    assert writes == [('update', {'lastRelapseDate': expected}),
                      ('delete', ('nicotineUsers', 'owner', 'journalEntries', 'target'))]
