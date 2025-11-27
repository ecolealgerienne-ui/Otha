-- AlterTable: Add OTP confirmation fields to Booking
ALTER TABLE "Booking" ADD COLUMN "confirmationOtp" TEXT;
ALTER TABLE "Booking" ADD COLUMN "confirmationOtpExpiresAt" TIMESTAMP(3);
ALTER TABLE "Booking" ADD COLUMN "confirmationOtpAttempts" INTEGER NOT NULL DEFAULT 0;

-- AlterTable: Add check-in geolocation fields to Booking
ALTER TABLE "Booking" ADD COLUMN "checkinAt" TIMESTAMP(3);
ALTER TABLE "Booking" ADD COLUMN "checkinLat" DOUBLE PRECISION;
ALTER TABLE "Booking" ADD COLUMN "checkinLng" DOUBLE PRECISION;

-- AlterTable: Add confirmation method field to Booking
ALTER TABLE "Booking" ADD COLUMN "confirmationMethod" TEXT;
