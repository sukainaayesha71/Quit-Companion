import pytest

from app.account_deletion.service import (
    AccountDeletionError,
    FirebaseAccountDeletionService,
    _delete_user_records,
)
from app.config import Settings


class FakeDocumentReference:
    def __init__(self, database, path):
        self.database = database
        self.path = path
        self.id = path[-1]

    def collection(self, name):
        return FakeCollection(self.database, (*self.path, name))

    def delete(self):
        self.database.documents.pop(self.path, None)

    def get(self):
        return type("Snapshot", (), {"exists": self.path in self.database.documents})()


class FakeDocument(FakeDocumentReference):
    @property
    def reference(self):
        return self


class FakeCollection:
    def __init__(self, database, path):
        self.database = database
        self.path = path

    def document(self, document_id):
        return FakeDocumentReference(self.database, (*self.path, document_id))

    def where(self, field, _operator, value):
        return FakeQuery(self.database, self.path, field, value)

    def stream(self):
        return [
            FakeDocument(self.database, path)
            for path in self.database.documents
            if len(path) == len(self.path) + 1 and path[:-1] == self.path
        ]


class FakeQuery(FakeCollection):
    def __init__(self, database, path, field, value):
        super().__init__(database, path)
        self.field = field
        self.value = value

    def stream(self):
        return [
            document
            for document in super().stream()
            if self.database.documents[document.path].get(self.field)
            == self.value
        ]


class FakeFirestore:
    def __init__(self, documents):
        self.documents = documents

    def collection(self, name):
        return FakeCollection(self, (name,))

    def recursive_delete(self, reference):
        for path in list(self.documents):
            if path[: len(reference.path)] == reference.path:
                del self.documents[path]


def test_delete_user_records_removes_private_and_authored_community_data():
    database = FakeFirestore(
        {
            ("nicotineUsers", "u1"): {},
            ("nicotineUsers", "u1", "cravingLogs", "c1"): {},
            ("communityPosts", "own-post"): {"userId": "u1"},
            ("communityPosts", "own-post", "replies", "other-reply"): {
                "userId": "u2"
            },
            ("communityPosts", "other-post"): {"userId": "u2"},
            ("communityPosts", "other-post", "likes", "u1"): {},
            ("communityPosts", "other-post", "likes", "u2"): {},
            ("communityPosts", "other-post", "replies", "own-reply"): {
                "userId": "u1"
            },
            ("communityPosts", "other-post", "replies", "other-reply"): {
                "userId": "u2"
            },
        }
    )

    _delete_user_records(database, "u1")

    assert not any(path[:2] == ("nicotineUsers", "u1") for path in database.documents)
    assert not any(path[:2] == ("communityPosts", "own-post") for path in database.documents)
    assert ("communityPosts", "other-post") in database.documents
    assert ("communityPosts", "other-post", "likes", "u1") not in database.documents
    assert ("communityPosts", "other-post", "replies", "own-reply") not in database.documents
    assert ("communityPosts", "other-post", "likes", "u2") in database.documents
    assert ("communityPosts", "other-post", "replies", "other-reply") in database.documents


def test_account_deletion_fails_closed_without_firebase_admin_configuration():
    service = FirebaseAccountDeletionService(
        Settings(firebase_service_account_json=None)
    )

    with pytest.raises(AccountDeletionError, match="not configured"):
        service.delete_account("u1")
