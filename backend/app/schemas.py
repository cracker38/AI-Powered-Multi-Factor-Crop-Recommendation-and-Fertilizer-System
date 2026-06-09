from datetime import datetime

from pydantic import BaseModel, Field


class FarmerFieldData(BaseModel):
    nitrogen: float = Field(ge=0, le=500)
    phosphorus: float = Field(ge=0, le=500)
    potassium: float = Field(ge=0, le=500)
    soil_moisture: float = Field(ge=0, le=100)
    temperature_c: float = Field(ge=-10, le=55)
    humidity_pct: float = Field(ge=0, le=100)
    soil_ph: float = Field(ge=0, le=14)
    rainfall_mm: float = Field(ge=0, le=2000)
    soil_type: str = Field(default="loam", max_length=40)


class UserProfile(BaseModel):
    id: str
    email: str
    display_name: str | None
    role: str
    disabled: bool
    phone: str | None = None
    district: str | None = None
    farm_size_ha: float | None = None
    approval_status: str = "approved"
    field_data: FarmerFieldData | None = None


class RegisterFarmerRequest(BaseModel):
    display_name: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=20)
    district: str | None = Field(default=None, max_length=80)
    farm_size_ha: float = Field(ge=0.01, le=10000, description="Farm size in hectares")
    field_data: FarmerFieldData | None = None


class SubmitFarmerFieldDataRequest(BaseModel):
    field_data: FarmerFieldData


class AdminApproveFarmerRequest(BaseModel):
    display_name: str = Field(min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=20)
    district: str | None = Field(default=None, max_length=80)
    farm_size_ha: float = Field(ge=0.01, le=10000)
    field_data: FarmerFieldData
    admin_notes: str | None = Field(default=None, max_length=500)


class UpdateFarmerProfileRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=2, max_length=120)
    phone: str | None = Field(default=None, max_length=20)
    district: str | None = Field(default=None, max_length=80)


class FarmerTipItem(BaseModel):
    id: str
    title: str
    message: str
    category: str = "tip"


class FarmConditionsRequest(BaseModel):
    nitrogen: float = Field(ge=0, le=500)
    phosphorus: float = Field(ge=0, le=500)
    potassium: float = Field(ge=0, le=500)
    soil_moisture: float = Field(ge=0, le=100)
    temperature_c: float = Field(ge=-10, le=55)
    humidity_pct: float = Field(ge=0, le=100)
    soil_ph: float = Field(ge=0, le=14)
    rainfall_mm: float = Field(ge=0, le=2000)
    soil_type: str = Field(default="loam", max_length=40)
    season: str | None = Field(default=None, max_length=40, description="Auto-detected from date if omitted")
    district: str | None = Field(default=None, max_length=80)
    persist: bool = True
    use_live_climate: bool = Field(
        default=True,
        description="When true, temperature, humidity, and rainfall are loaded from live weather APIs for the district.",
    )


class FertilizerRecommendationItem(BaseModel):
    name: str
    type: str
    application_rate: str
    timing: str
    purpose: str
    priority: str
    npk: str = "—"


class NutrientAnalysis(BaseModel):
    current: dict[str, float]
    optimal: dict[str, float]
    gaps_kg_per_ha: dict[str, float]
    soil_ph: float
    soil_type: str
    season: str
    district: str | None = None


class ForecastDayItem(BaseModel):
    date: str
    precipitation_mm: float = 0
    temp_max_c: float | None = None
    temp_min_c: float | None = None


class LiveClimateResponse(BaseModel):
    available: bool
    temperature_c: float | None = None
    humidity_pct: float | None = None
    rainfall_mm: float | None = None
    district: str = "Kigali"
    source: str = ""
    provider_url: str = ""
    secondary_source: str = ""
    fetched_at: str | None = None
    note: str = ""
    reason: str = ""
    forecast_daily: list[ForecastDayItem] = []


class WeatherInsight(BaseModel):
    season_name: str
    season_months: str
    seasonal_rainfall: str
    seasonal_advice: str
    district_note: str = ""
    alerts: list[str] = []
    forecast_note: str = ""
    live_available: bool = False
    live_temperature_c: float | None = None
    live_humidity_pct: float | None = None
    forecast_precipitation_mm_7d: float | None = None
    forecast_daily: list[ForecastDayItem] = []
    live_data_source: str = ""


class OutcomeFeedbackRequest(BaseModel):
    prediction_id: str = Field(min_length=1, max_length=128)
    yield_rating: int = Field(ge=1, le=5, description="1=poor, 5=excellent")
    crop_grown: str | None = Field(default=None, max_length=80)
    followed_fertilizer: bool = True
    notes: str | None = Field(default=None, max_length=500)


class OutcomeFeedbackItem(BaseModel):
    id: str
    prediction_id: str
    recommended_crop: str
    crop_grown: str | None = None
    yield_rating: int
    followed_fertilizer: bool
    notes: str | None = None
    created_at: datetime | None = None


class CropRankItem(BaseModel):
    crop: str
    confidence: float


class PredictionDetailItem(BaseModel):
    id: str
    top_crop: str
    top_confidence: float
    explanation: str
    model_version: str
    created_at: datetime
    nitrogen: float
    phosphorus: float
    potassium: float
    soil_moisture: float
    temperature_c: float
    humidity_pct: float
    soil_ph: float
    rainfall_mm: float
    soil_type: str = "loam"
    season: str = "season_a"
    district: str | None = None
    soil_health_score: float = 0
    soil_health_label: str = ""
    fertilizers: list[FertilizerRecommendationItem] = []
    nutrient_analysis: NutrientAnalysis | None = None
    weather_insight: WeatherInsight | None = None
    precision_notes: list[str] = []
    environment_analysis: list[str] = []
    full_ranking: list[CropRankItem] = []
    has_feedback: bool = False
    feedback_rating: int | None = None
    season_label: str = ""
    improvement_actions: list[str] = []


class CropPredictionResponse(BaseModel):
    top_crop: str
    top_confidence: float
    explanation: str
    full_ranking: list[CropRankItem]
    model_version: str
    prediction_id: str | None = None
    soil_health_score: float = 0
    soil_health_label: str = ""
    fertilizers: list[FertilizerRecommendationItem] = []
    nutrient_analysis: NutrientAnalysis | None = None
    weather_insight: WeatherInsight | None = None
    precision_notes: list[str] = []
    environment_analysis: list[str] = []
    season_used: str = "season_a"
    season_label: str = ""
    improvement_actions: list[str] = []


class PredictionHistoryItem(BaseModel):
    id: str
    top_crop: str
    top_confidence: float
    created_at: datetime
    soil_ph: float
    nitrogen: float
    soil_type: str = "loam"
    season: str = "season_a"
    soil_health_score: float = 0


class AdminUserItem(BaseModel):
    id: str
    email: str
    display_name: str | None
    role: str
    disabled: bool
    created_at: datetime
    prediction_count: int = 0
    phone: str | None = None
    district: str | None = None
    farm_size_ha: float | None = None
    approval_status: str = "approved"
    field_data: FarmerFieldData | None = None


class AdminUserUpdate(BaseModel):
    display_name: str | None = None
    disabled: bool | None = None


class DatasetItem(BaseModel):
    id: str
    name: str
    filename: str
    row_count: int
    is_active: bool
    created_at: datetime


class DatasetUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=120)


class ModelStatusResponse(BaseModel):
    model_loaded: bool
    model_version: str | None
    meta: dict | None
    training_datasets_count: int
    total_predictions: int
    total_farmers: int
    active_farmers: int = 0
    disabled_farmers: int = 0
    avg_predictions_per_farmer: float = 0.0
    crop_distribution: dict[str, int] = {}
    model_accuracy: float | None = None
    model_precision: float | None = None
    model_recall: float | None = None
    model_f1: float | None = None
    last_trained_at: datetime | None = None
    fertilizer_usage: dict[str, int] = {}
    avg_soil_health_score: float = 0.0
    outcome_feedback_count: int = 0
    avg_outcome_rating: float | None = None
    fertilizer_follow_rate_pct: float | None = None


class TrainModelResponse(BaseModel):
    success: bool
    best_model: str
    accuracy: float
    precision: float | None = None
    recall: float | None = None
    f1: float | None = None
    message: str


class ActivityLogItem(BaseModel):
    id: str
    actor_uid: str
    actor_email: str
    action: str
    category: str
    detail: str
    severity: str
    created_at: datetime | None = None


class NotificationItem(BaseModel):
    id: str
    title: str
    message: str
    category: str
    severity: str
    read: bool
    created_at: datetime | None = None


class ModelReportResponse(BaseModel):
    model_loaded: bool
    model_version: str | None
    meta: dict | None
    training_report_text: str | None = None


class AdminPredictionItem(BaseModel):
    id: str
    user_uid: str
    top_crop: str
    top_confidence: float
    model_version: str
    created_at: datetime | None = None
    farmer_email: str | None = None
    farmer_name: str | None = None
    district: str | None = None
    season: str | None = None
    soil_type: str | None = None
    soil_health_score: float = 0.0
    soil_ph: float | None = None
    nitrogen: float | None = None
    phosphorus: float | None = None
    potassium: float | None = None
