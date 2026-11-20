from datetime import datetime, time

from fastapi import APIRouter, Depends, HTTPException, Response
from starlette.concurrency import run_in_threadpool

from ..coaching.router import CoachingContext
from ..firebase_auth_dependency import require_firebase_uid

router = APIRouter(tags=["content"])


class ContentStore:
    def database(self):
        return CoachingContext().database()

    def delete_post(self, uid: str, post_id: str):
        db = self.database()
        reference = db.collection("communityPosts").document(post_id)
        snapshot = reference.get()
        if not snapshot.exists: return
        if (snapshot.to_dict() or {}).get("userId") != uid:
            raise PermissionError("Only the author can delete a post")
        # Client rules cannot safely cascade through other users' replies.
        db.recursive_delete(reference)

    def delete_journal(self, uid: str, entry_id: str):
        from firebase_admin import firestore
        db = self.database()
        user = db.collection("nicotineUsers").document(uid)
        entry = user.collection("journalEntries").document(entry_id)

        @firestore.transactional
        def remove(transaction):
            snapshot = entry.get(transaction=transaction)
            if not snapshot.exists: return
            data = snapshot.to_dict() or {}
            if data.get("relapseFlag"):
                profile = user.get(transaction=transaction)
                remaining = [doc.to_dict() or {} for doc in user.collection("journalEntries").stream(transaction=transaction)
                             if doc.id != entry_id]
                dates = [datetime.fromisoformat(row["entryDate"]).date() for row in remaining
                         if row.get("relapseFlag") and row.get("entryDate")]
                latest = datetime.combine(max(dates), time.min).isoformat() if dates else None
                if profile.exists: transaction.update(user, {"lastRelapseDate": latest})
            transaction.delete(entry)
        remove(db.transaction())


def get_content_store(): return ContentStore()


@router.delete("/community/posts/{post_id}", status_code=204)
async def delete_post(post_id: str, uid: str = Depends(require_firebase_uid), store: ContentStore = Depends(get_content_store)):
    try:
        await run_in_threadpool(store.delete_post, uid, post_id)
    except PermissionError as exc:
        raise HTTPException(403, "You can only delete your own posts.") from exc
    except Exception as exc:
        raise HTTPException(503, "Could not delete your post. Please try again.") from exc
    return Response(status_code=204)


@router.delete("/journal/entries/{entry_id}", status_code=204)
async def delete_journal(entry_id: str, uid: str = Depends(require_firebase_uid), store: ContentStore = Depends(get_content_store)):
    try:
        await run_in_threadpool(store.delete_journal, uid, entry_id)
    except Exception as exc:
        raise HTTPException(503, "Could not delete your journal entry. Please try again.") from exc
    return Response(status_code=204)
