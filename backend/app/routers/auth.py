from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings
from app.deps import get_current_user
from app.firebase_app import token_uid, verify_id_token
from app.firestore_db import UserRecord, get_user, get_user_by_email, upsert_user
from app.firestore_timeout import run_firestore
from app.schemas import RegisterFarmerRequest, UpdateFarmerProfileRequest, UserProfile

router = APIRouter(prefix="/auth", tags=["auth"])
bearer = HTTPBearer()


def _firestore_user(uid: str) -> UserRecord | None:
    """Load user from Firestore with a timeout (invalid service account keys hang)."""
    return run_firestore("profile lookup", get_user, uid)


def _profile(user: UserRecord) -> UserProfile:
    return UserProfile(
        id=user.uid,
        email=user.email,
        display_name=user.display_name,
        role=user.role,
        disabled=user.disabled,
        phone=user.phone,
        district=user.district,
    )


@router.post("/register-farmer", response_model=UserProfile)
def register_farmer(
    body: RegisterFarmerRequest,
    creds: HTTPAuthorizationCredentials = Depends(bearer),
):
    """Create farmer profile after Firebase sign-up. Admin email cannot register as farmer."""
    try:
        decoded = verify_id_token(creds.credentials)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from None

    uid = token_uid(decoded)
    email = (decoded.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="Email required in Firebase account")

    if email == settings.admin_email_normalized:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This email is reserved for system administration and cannot be used for farmer registration.",
        )

    existing = run_firestore("user lookup", get_user, uid)
    if existing:
        if existing.role == "admin":
            raise HTTPException(status_code=403, detail="Admin accounts cannot use farmer registration")
        user = run_firestore(
            "profile update",
            upsert_user,
            uid,
            email=email,
            display_name=body.display_name,
            role="farmer",
            disabled=False,
            phone=body.phone,
            district=body.district,
        )
        return _profile(user)

    if run_firestore("email lookup", get_user_by_email, email):
        raise HTTPException(status_code=409, detail="Email already registered")

    user = run_firestore(
        "profile create",
        upsert_user,
        uid,
        email=email,
        display_name=body.display_name,
        role="farmer",
        disabled=False,
        phone=body.phone,
        district=body.district,
    )
    return _profile(user)


@router.patch("/profile", response_model=UserProfile)
def update_profile(
    body: UpdateFarmerProfileRequest,
    user: UserRecord = Depends(get_current_user),
):
    if user.role != "farmer":
        raise HTTPException(status_code=403, detail="Only farmers can update this profile")
    updates = {}
    if body.display_name is not None:
        updates["display_name"] = body.display_name
    if body.phone is not None:
        updates["phone"] = body.phone
    if body.district is not None:
        updates["district"] = body.district
    if not updates:
        return _profile(user)
    from app.firestore_db import update_user

    updated = update_user(user.uid, **updates)
    return _profile(updated)  # type: ignore[arg-type]


@router.get("/me", response_model=UserProfile)
def me(user: UserRecord = Depends(get_current_user)):
    return _profile(user)


@router.post("/sync", response_model=UserProfile)
def sync_after_login(creds: HTTPAuthorizationCredentials = Depends(bearer)):
    """Called after Firebase login. Returns profile if user exists (farmer or admin)."""
    try:
        decoded = verify_id_token(creds.credentials)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token") from None

    uid = token_uid(decoded)
    email = (decoded.get("email") or "").strip().lower()
    user = get_user(uid)
    if user is None and email == settings.admin_email_normalized:
        upsert_user(
            uid,
            email=email,
            display_name="System Administrator",
            role="admin",
            disabled=False,
        )
        user = get_user(uid)
    if user is None:
        if email == settings.admin_email_normalized:
            raise HTTPException(
                status_code=403,
                detail="Admin account not provisioned. Run backend/scripts/seed_admin.py first.",
            )
        raise HTTPException(
            status_code=404,
            detail="No profile found. Farmers must complete registration.",
        )
    if user.disabled:
        raise HTTPException(status_code=403, detail="Account disabled")
    return _profile(user)
