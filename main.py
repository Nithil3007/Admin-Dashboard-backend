from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import psycopg2
from psycopg2.extras import DictCursor
import os
import uvicorn

app = FastAPI()

# CORS Middleware - Allow frontend origins
origins = [
    "http://localhost:3000",
    "http://localhost:8000",
    "https://main.d2yed3nptgomb1.amplifyapp.com",
    "https://*.amplifyapp.com",  # Allow all Amplify branches
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Database connection settings - use environment variable or default to Aurora
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:password@mediscribe-aurora-cluster.cluster-czocg06qii0u.us-east-2.rds.amazonaws.com:5432/mednotescribe"
)

# Dependency to get a DB connection
def get_db_conn():
    conn = None
    try:
        conn = psycopg2.connect(DATABASE_URL)
        yield conn
    finally:
        if conn:
            conn.close()

# Models
class UserStats(BaseModel):
    user_id: str
    full_name: str
    email: str
    patient_count: int
    successful_recordings: int
    failed_recordings: int
    total_hours: float
    avg_length_seconds: float
    avg_file_size_bytes: float
    tier_name: Optional[str] = None

class FeatureFlags(BaseModel):
    features: dict

class TierUpdate(BaseModel):
    tier_name: str

# Health check endpoint
@app.get("/")
async def health_check():
    return {"status": "healthy", "service": "admin-portal-backend"}

# Admin API Endpoints
@app.get("/admin/users/stats", response_model=List[UserStats])
async def get_user_stats(conn: psycopg2.extensions.connection = Depends(get_db_conn)):
    print("Received request for /admin/users/stats")
    with conn.cursor(cursor_factory=DictCursor) as cur:
        cur.execute("""SELECT u.user_id, u.full_name, u.email,
                        COUNT(DISTINCT p.patient_id) as patient_count,
                        COUNT(CASE WHEN j.status = 'completed' THEN 1 END) as successful_recordings,
                        COUNT(CASE WHEN j.status = 'failed' THEN 1 END) as failed_recordings,
                        t.name as tier_name
                        FROM users u
                        LEFT JOIN patients p ON u.user_id = p.doctor_id
                        LEFT JOIN jobs j ON u.user_id = j.doctor_id
                        LEFT JOIN user_tiers ut ON u.user_id = ut.user_id AND ut.is_active = true
                        LEFT JOIN tiers t ON ut.tier_id = t.id
                        GROUP BY u.user_id, u.full_name, u.email, t.name;""")

        results = cur.fetchall()
        
        stats_list = [
            UserStats(
                user_id=str(row['user_id']),
                full_name=row['full_name'],
                email=row['email'],
                patient_count=row['patient_count'],
                successful_recordings=row['successful_recordings'],
                failed_recordings=row['failed_recordings'],
                # Provide default values for the missing fields
                total_hours=0.0,
                avg_length_seconds=0.0,
                avg_file_size_bytes=0.0,
                tier_name=row['tier_name']
            ) for row in results
        ]
        return stats_list

@app.post("/admin/users/{user_id}/upgrade")
async def upgrade_user_tier(user_id: str, tier: TierUpdate, conn: psycopg2.extensions.connection = Depends(get_db_conn)):
    try:
        with conn.cursor() as cur:
            # Verify user exists
            cur.execute("SELECT user_id FROM users WHERE user_id = %s", (user_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
            
            # Get the new tier_id
            cur.execute("SELECT id FROM tiers WHERE name = %s AND status = 'active'", (tier.tier_name,))
            new_tier_id_row = cur.fetchone()
            if not new_tier_id_row:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tier not found or inactive")
            new_tier_id = new_tier_id_row[0]

            # Deactivate any existing active tier for this user
            cur.execute("""UPDATE user_tiers 
                          SET is_active = false, 
                              updated_at = NOW() 
                          WHERE user_id = %s AND is_active = true""",
                       (user_id,))
            
            # Insert new active tier assignment
            cur.execute("""INSERT INTO user_tiers (user_id, tier_id, is_active, assigned_by, assigned_at)
                          VALUES (%s, %s, true, 'admin', NOW())""",
                       (user_id, new_tier_id))

        conn.commit()
        return {"status": "success", "message": f"User {user_id}'s tier upgraded to {tier.tier_name}"}
    except HTTPException:
        conn.rollback()
        raise
    except psycopg2.Error as e:
        conn.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Database error: {str(e)}")
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

# @app.put("/admin/users/{user_id}/features")
# async def update_feature_flags(user_id: str, flags: FeatureFlags, token: str = Depends(oauth2_scheme)):
#     if not is_admin(token):
#         raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        
#     cur = conn.cursor()
#     try:
#         cur.execute(
#             """INSERT INTO admin_feature_flags (user_id, features)
#             VALUES (%s, %s)
#             ON CONFLICT (user_id) DO UPDATE 
#             SET features = EXCLUDED.features,
#                 updated_at = NOW()"""
#         , (user_id, flags.features))
#         conn.commit()
#         return {"status": "success"}
#     except Exception as e:
#         conn.rollback()
#         raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
if __name__ == '__main__':
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
