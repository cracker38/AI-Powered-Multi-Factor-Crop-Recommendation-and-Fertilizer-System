from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings
from app.deps import get_current_user, require_farmer
from app.firebase_app import token_uid, verify_id_token
from app.firestore_db import UserRecord, get_user, get_user_by_email, update_user, upsert_user
from app.firestore_timeout import run_firestore
from app.schemas import (
    RegisterFarmerRequest,
    SubmitFarmerFieldDataRequest,
    UpdateFarmerProfileRequest,
    UserProfile,
)
from app.user_profile_utils import user_to_profile
from app.weather_service import apply_live_climate

router = APIRouter(prefix="/auth", tags=["auth"])
bearer = HTTPBearer()


def _profile(user: UserRecord) -> UserProfile:
    return user_to_profile(user)


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

    field_data = body.field_data.model_dump() if body.field_data else None

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
            farm_size_ha=body.farm_size_ha,
            approval_status="pending",
            field_data=field_data,
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
        farm_size_ha=body.farm_size_ha,
        approval_status="pending",
        field_data=field_data,
    )
    return _profile(user)


@router.patch("/profile", response_model=UserProfile)
def update_profile(
    body: UpdateFarmerProfileRequest,
    user: UserRecord = Depends(require_farmer),
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
    updated = update_user(user.uid, **updates)
    return _profile(updated)  # type: ignore[arg-type]


@router.post("/field-data", response_model=UserProfile)
def submit_field_data(
    body: SubmitFarmerFieldDataRequest,
    user: UserRecord = Depends(require_farmer),
):
    """Pending farmers submit soil/climate readings for admin review."""
    if user.approval_status == "approved":
        raise HTTPException(status_code=400, detail="Account already approved")
    if user.approval_status == "rejected":
        raise HTTPException(status_code=403, detail="Account was rejected. Contact your extension officer.")
    fd = body.field_data
    temp, hum, rain, _ = apply_live_climate(
        district=getattr(user, "district", None),
        temperature_c=fd.temperature_c,
        humidity_pct=fd.humidity_pct,
        rainfall_mm=fd.rainfall_mm,
    )
    field_data = fd.model_copy(
        update={"temperature_c": temp, "humidity_pct": hum, "rainfall_mm": rain}
    ).model_dump()
    updated = update_user(user.uid, field_data=field_data)
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
            approval_status="approved",
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
