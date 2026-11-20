import logging

from ..config import Settings

logger = logging.getLogger(__name__)


class AccountDeletionError(Exception):
    """Raised when account data or the Firebase Auth account cannot be removed."""


class FirebaseAccountDeletionService:
    def __init__(self, settings: Settings):
        self._settings = settings
        self._app = None

    def delete_account(self, user_id: str) -> None:
        firebase_admin, credentials, auth, firestore = self._firebase_modules()
        app = self._firebase_app(firebase_admin, credentials)
        try:
            db = firestore.client(app=app)
            _delete_user_records(db, user_id)
            try:
                auth.delete_user(user_id, app=app)
            except auth.UserNotFoundError:
                pass
        except Exception as exc:
            logger.exception("Account deletion failed.")
            raise AccountDeletionError(
                "Could not delete the account's data. Please try again."
            ) from exc

    def _firebase_modules(self):
        if not self._settings.firebase_service_account_json:
            raise AccountDeletionError("Account deletion is not configured.")
        import firebase_admin
        from firebase_admin import auth, credentials, firestore

        return firebase_admin, credentials, auth, firestore

    def _firebase_app(self, firebase_admin, credentials):
        if self._app is not None:
            return self._app
        try:
            self._app = firebase_admin.get_app("quit-companion-account-deletion")
        except ValueError:
            try:
                credential = credentials.Certificate(
                    self._settings.firebase_service_account_json
                )
                self._app = firebase_admin.initialize_app(
                    credential, name="quit-companion-account-deletion"
                )
            except Exception as exc:
                raise AccountDeletionError(
                    "Firebase Admin SDK is not configured correctly."
                ) from exc
        return self._app


def _delete_user_records(db, user_id: str) -> None:
    user_ref = db.collection("nicotineUsers").document(user_id)
    db.recursive_delete(user_ref)

    posts = db.collection("communityPosts")
    owned_posts = list(posts.where("userId", "==", user_id).stream())
    owned_post_ids = {post.id for post in owned_posts}
    for post in owned_posts:
        db.recursive_delete(post.reference)

    for post in posts.stream():
        if post.id in owned_post_ids:
            continue
        likes = post.reference.collection("likes")
        likes.document(user_id).delete()
        replies = post.reference.collection("replies")
        for reply in replies.where("userId", "==", user_id).stream():
            reply.reference.delete()
