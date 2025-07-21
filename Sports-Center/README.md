# Sports Facility Management Smart Contract

A comprehensive Clarity smart contract for managing sports facilities, bookings, payments, and maintenance on the Stacks blockchain.

## Overview

This smart contract provides a complete solution for sports facility management, enabling facility owners to list their venues, users to book time slots, and administrators to manage the platform. The contract handles payments, availability tracking, maintenance scheduling, and revenue management.

## Features

### **Facility Management**
- Register and update facility information
- Set hourly rates and capacity
- Manage amenities and descriptions
- Toggle facility availability
- Owner approval system

### **User Management**
- User profile creation and updates
- Membership level tracking
- Booking history maintenance
- Account status management

### **Booking System**
- Time slot availability checking
- Automated booking creation
- Payment processing with platform fees
- Check-in/check-out functionality
- Cancellation with refund policy

### **Maintenance Management**
- Schedule maintenance activities
- Track maintenance status and costs
- Assign maintenance to personnel
- Maintain facility uptime records

### **Revenue Management**
- Automated revenue tracking
- Platform fee collection (2.5% default)
- Monthly revenue statistics
- Owner payment distribution

## Contract Constants

```clarity
CONTRACT-OWNER          ; Contract deployer address
ERR-UNAUTHORIZED (100)  ; Access denied
ERR-NOT-FOUND (101)     ; Resource not found
ERR-ALREADY-EXISTS (102); Duplicate resource
ERR-INVALID-PARAMS (103); Invalid parameters
ERR-INSUFFICIENT-FUNDS (104) ; Not enough STX
ERR-BOOKING-CONFLICT (105)   ; Time slot unavailable
ERR-BOOKING-EXPIRED (106)    ; Booking past deadline
ERR-FACILITY-UNAVAILABLE (107) ; Facility inactive
ERR-INVALID-TIME-SLOT (108)  ; Invalid time parameters
```

## Data Structures

### Facilities
- **facility-id**: Unique identifier
- **name**: Facility name (max 100 chars)
- **description**: Detailed description (max 500 chars)
- **location**: Physical location (max 200 chars)
- **capacity**: Maximum occupancy
- **hourly-rate**: Cost per hour in STX
- **owner**: Facility owner principal
- **amenities**: List of available amenities
- **timestamps**: Created/updated timestamps

### Bookings
- **booking-id**: Unique identifier
- **facility-id**: Associated facility
- **user**: Booking user principal
- **start-time/end-time**: Booking duration
- **total-cost**: Final cost including fees
- **status**: pending → confirmed → checked-in → completed
- **payment-status**: pending → paid → refunded
- **special-requests**: Custom requirements

### User Profiles
- **user**: User principal
- **contact-info**: Name, email, phone
- **membership-level**: basic/premium/vip
- **total-bookings**: Booking count
- **account-status**: Active/inactive

## Key Functions

### Facility Management

#### `register-facility`
```clarity
(register-facility 
  (name (string-ascii 100))
  (description (string-ascii 500))
  (location (string-ascii 200))
  (capacity uint)
  (hourly-rate uint)
  (amenities (list 10 (string-ascii 50))))
```
Register a new sports facility.

#### `update-facility`
Update existing facility information (owner only).

#### `toggle-facility-status`
Activate/deactivate facility availability.

### User Management

#### `create-user-profile`
```clarity
(create-user-profile 
  (name (string-ascii 100))
  (email (string-ascii 100))
  (phone (string-ascii 20)))
```
Create a new user profile.

### Booking Management

#### `create-booking`
```clarity
(create-booking 
  (facility-id uint)
  (start-time uint)
  (duration-hours uint)
  (special-requests (string-ascii 300)))
```
Create a new booking reservation.

#### `pay-for-booking`
Process payment and confirm booking.

#### `cancel-booking`
Cancel booking with refund (90% refund if cancelled >2 hours before).

#### `check-in-booking` / `complete-booking`
Manage booking lifecycle.

### Read-Only Functions

#### `get-facility` / `get-booking` / `get-user-profile`
Retrieve data records.

#### `check-availability`
Check time slot availability for a facility.

#### `calculate-booking-cost`
Calculate total cost including platform fees.

#### `get-facility-revenue`
Get revenue statistics for a facility and period.

## Usage Examples

### 1. Register a New Facility
```clarity
(register-facility 
  "Downtown Tennis Court"
  "Professional tennis court with lighting and equipment rental"
  "123 Main St, Downtown"
  u4
  u50  ;; 50 STX per hour
  (list "Lighting" "Equipment Rental" "Parking"))
```

### 2. Create a User Profile
```clarity
(create-user-profile 
  "John Doe"
  "john@example.com"
  "+1-555-0123")
```

### 3. Make a Booking
```clarity
;; Create booking for 2 hours starting at timestamp
(create-booking u1 u1640995200 u2 "Need extra equipment")

;; Pay for the booking
(pay-for-booking u1)
```

### 4. Check Availability
```clarity
;; Check if facility 1 is available on date for 2-hour slot
(check-availability u1 u20231201 u14 u16)  ;; 2-4 PM
```

## Platform Economics

- **Platform Fee**: 2.5% of booking value (adjustable by admin)
- **Cancellation Policy**: 90% refund if cancelled >2 hours before
- **Check-in Window**: 30 minutes before to 30 minutes after start time
- **Maximum Booking Duration**: 12 hours
- **Revenue Tracking**: Monthly aggregation per facility

## Security Features

- **Access Control**: Owner-only functions for facility management
- **Input Validation**: Parameter checking for all inputs
- **Time Validation**: Prevents past bookings and invalid time slots
- **Payment Security**: Atomic payment transfers with proper error handling
- **Availability Locking**: Prevents double bookings through slot reservation

## Administrative Functions

### `set-platform-fee-rate`
Adjust platform fee (contract owner only, max 10%).

### `approve-facility-owner`
Approve new facility owners (contract owner only).

## Error Handling

The contract includes comprehensive error handling for:
- Unauthorized access attempts
- Invalid parameters and time slots
- Insufficient funds
- Booking conflicts
- Resource not found errors

## Deployment Notes

1. **Prerequisites**: Stacks blockchain testnet/mainnet access
2. **Dependencies**: None (pure Clarity implementation)
3. **Initial Setup**: Deploy contract and set initial platform fee
4. **Owner Approval**: Admin must approve facility owners before registration