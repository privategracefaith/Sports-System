;; Sports Facility Management Smart Contract
;; A comprehensive system for managing sports facilities, bookings, and payments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-PARAMS (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-BOOKING-CONFLICT (err u105))
(define-constant ERR-BOOKING-EXPIRED (err u106))
(define-constant ERR-FACILITY-UNAVAILABLE (err u107))
(define-constant ERR-INVALID-TIME-SLOT (err u108))
(define-constant ERR-ALREADY-CHECKED-IN (err u109))
(define-constant ERR-NOT-CHECKED-IN (err u110))
(define-constant ERR-INVALID-STRING (err u111))

;; Data Variables
(define-data-var next-facility-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var next-maintenance-id uint u1)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Data Maps
(define-map facilities
    { facility-id: uint }
    {
        name: (string-ascii 100),
        description: (string-ascii 500),
        location: (string-ascii 200),
        capacity: uint,
        hourly-rate: uint,
        owner: principal,
        is-active: bool,
        amenities: (list 10 (string-ascii 50)),
        created-at: uint,
        updated-at: uint
    }
)

(define-map bookings
    { booking-id: uint }
    {
        facility-id: uint,
        user: principal,
        start-time: uint,
        end-time: uint,
        total-cost: uint,
        status: (string-ascii 20), ;; "pending", "confirmed", "checked-in", "completed", "cancelled"
        payment-status: (string-ascii 20), ;; "pending", "paid", "refunded"
        created-at: uint,
        updated-at: uint,
        special-requests: (string-ascii 300)
    }
)

(define-map maintenance-records
    { maintenance-id: uint }
    {
        facility-id: uint,
        maintenance-type: (string-ascii 50), ;; "routine", "repair", "upgrade"
        description: (string-ascii 500),
        scheduled-date: uint,
        completion-date: (optional uint),
        cost: uint,
        status: (string-ascii 20), ;; "scheduled", "in-progress", "completed", "cancelled"
        assigned-to: (optional principal),
        created-by: principal,
        created-at: uint
    }
)

(define-map user-profiles
    { user: principal }
    {
        name: (string-ascii 100),
        email: (string-ascii 100),
        phone: (string-ascii 20),
        membership-level: (string-ascii 20), ;; "basic", "premium", "vip"
        total-bookings: uint,
        created-at: uint,
        is-active: bool
    }
)

(define-map facility-owners
    { owner: principal }
    { is-approved: bool, facilities-count: uint }
)

;; Time slot tracking for availability
(define-map facility-availability
    { facility-id: uint, date: uint, hour: uint }
    { is-available: bool, booking-id: (optional uint) }
)

;; Revenue tracking
(define-map facility-revenue
    { facility-id: uint, period: uint } ;; period as YYYYMM
    { total-revenue: uint, booking-count: uint }
)

;; Input validation functions
(define-private (is-valid-ascii-string (input (string-ascii 1000)))
    (let ((input-len (len input)))
        (and (> input-len u0)
             (<= input-len u1000)
             ;; Basic validation - just check for non-empty and reasonable length
             ;; Clarity string-ascii type already ensures ASCII characters only
             true
        )
    )
)

(define-private (is-valid-phone (phone (string-ascii 20)))
    (and (> (len phone) u0)
         (<= (len phone) u20)
         ;; Basic phone validation - allow digits, spaces, hyphens, parentheses, plus
         (is-valid-ascii-string phone)
    )
)

(define-private (is-valid-email (email (string-ascii 100)))
    (and (> (len email) u4) ;; Minimum "a@b"
         (<= (len email) u100)
         (is-some (index-of email "@"))
         (is-some (index-of email "."))
         (is-valid-ascii-string email)
    )
)

(define-private (is-valid-maintenance-type (maintenance-type (string-ascii 50)))
    (or (is-eq maintenance-type "routine")
        (is-eq maintenance-type "repair")
        (is-eq maintenance-type "upgrade")
        (is-eq maintenance-type "inspection")
        (is-eq maintenance-type "cleaning")
    )
)

;; Enhanced validation functions that satisfy Clarinet's static analysis
(define-private (validate-and-get-name (input (string-ascii 100)))
    (if (and (> (len input) u0) (<= (len input) u100))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-and-get-description (input (string-ascii 500)))
    (if (and (>= (len input) u0) (<= (len input) u500))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-and-get-location (input (string-ascii 200)))
    (if (and (>= (len input) u0) (<= (len input) u200))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-and-get-phone (input (string-ascii 20)))
    (if (and (> (len input) u0) (<= (len input) u20))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-and-get-email (input (string-ascii 100)))
    (if (and (> (len input) u0) (<= (len input) u100))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-and-get-special-requests (input (string-ascii 300)))
    (if (and (>= (len input) u0) (<= (len input) u300))
        (ok input)
        ERR-INVALID-STRING
    )
)

(define-private (validate-amenities (amenities (list 10 (string-ascii 50))))
    (fold check-amenity-item amenities true)
)

(define-private (check-amenity-item (amenity (string-ascii 50)) (acc bool))
    (and acc (is-valid-ascii-string amenity) (<= (len amenity) u50))
)

;; Read-only functions
(define-read-only (get-facility (facility-id uint))
    (map-get? facilities { facility-id: facility-id })
)

(define-read-only (get-booking (booking-id uint))
    (map-get? bookings { booking-id: booking-id })
)

(define-read-only (get-maintenance-record (maintenance-id uint))
    (map-get? maintenance-records { maintenance-id: maintenance-id })
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles { user: user })
)

(define-read-only (is-facility-owner (owner principal))
    (default-to false (get is-approved (map-get? facility-owners { owner: owner })))
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (check-availability (facility-id uint) (date uint) (start-hour uint) (end-hour uint))
    (if (and (< start-hour end-hour) (<= end-hour u24))
        (ok (check-single-slot facility-id date start-hour))
        (ok false)
    )
)

(define-read-only (get-facility-revenue (facility-id uint) (period uint))
    (default-to { total-revenue: u0, booking-count: u0 }
        (map-get? facility-revenue { facility-id: facility-id, period: period })
    )
)

(define-read-only (calculate-booking-cost (facility-id uint) (hours uint))
    (match (get-facility facility-id)
        facility-data (let ((hourly-rate (get hourly-rate facility-data))
                           (base-cost (* hourly-rate hours))
                           (platform-fee (/ (* base-cost (var-get platform-fee-rate)) u10000)))
                          (ok (+ base-cost platform-fee)))
        ERR-NOT-FOUND
    )
)

;; Private helper functions
(define-private (check-single-slot (facility-id uint) (date uint) (hour uint))
    (default-to true 
        (get is-available 
             (map-get? facility-availability 
                      { facility-id: facility-id, date: date, hour: hour })))
)

(define-private (set-slot-status (facility-id uint) (date uint) (hour uint) (available bool) (booking-id (optional uint)))
    (map-set facility-availability
        { facility-id: facility-id, date: date, hour: hour }
        { is-available: available, booking-id: booking-id }
    )
)

(define-private (get-date-from-timestamp (timestamp uint))
    ;; Simplified date extraction (YYYYMMDD format)
    ;; In production, you'd want more sophisticated date handling
    (/ timestamp u86400) ;; Convert to days since epoch
)

(define-private (get-hour-from-timestamp (timestamp uint))
    (mod (/ timestamp u3600) u24) ;; Get hour of day
)

(define-private (update-revenue-stats (facility-id uint) (amount uint))
    (let ((current-period (/ (unwrap-panic (get-block-info? time (- block-height u1))) u2629746)) ;; Approximate month
          (current-stats (get-facility-revenue facility-id current-period)))
        (map-set facility-revenue
            { facility-id: facility-id, period: current-period }
            { 
                total-revenue: (+ (get total-revenue current-stats) amount),
                booking-count: (+ (get booking-count current-stats) u1)
            }
        )
    )
)

;; Public functions

;; Facility Management
(define-public (register-facility (name (string-ascii 100))
                                 (description (string-ascii 500))
                                 (location (string-ascii 200))
                                 (capacity uint)
                                 (hourly-rate uint)
                                 (amenities (list 10 (string-ascii 50))))
    (let ((facility-id (var-get next-facility-id))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        ;; Validate all inputs first
        (asserts! (> capacity u0) ERR-INVALID-PARAMS)
        (asserts! (> hourly-rate u0) ERR-INVALID-PARAMS)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
        (asserts! (<= (len name) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len description) u500) ERR-INVALID-PARAMS)
        (asserts! (<= (len location) u200) ERR-INVALID-PARAMS)
        (asserts! (validate-amenities amenities) ERR-INVALID-STRING)
        
        (map-set facilities
            { facility-id: facility-id }
            {
                name: name,
                description: description,
                location: location,
                capacity: capacity,
                hourly-rate: hourly-rate,
                owner: tx-sender,
                is-active: true,
                amenities: amenities,
                created-at: current-time,
                updated-at: current-time
            }
        )
        
        ;; Update owner registry
        (let ((current-owner-data (default-to { is-approved: true, facilities-count: u0 } 
                                             (map-get? facility-owners { owner: tx-sender }))))
            (map-set facility-owners
                { owner: tx-sender }
                { 
                    is-approved: (get is-approved current-owner-data),
                    facilities-count: (+ (get facilities-count current-owner-data) u1)
                }
            )
        )
        
        (var-set next-facility-id (+ facility-id u1))
        (ok facility-id)
    )
)

(define-public (update-facility (facility-id uint)
                               (name (string-ascii 100))
                               (description (string-ascii 500))
                               (location (string-ascii 200))
                               (capacity uint)
                               (hourly-rate uint)
                               (amenities (list 10 (string-ascii 50))))
    (let ((facility-data (unwrap! (get-facility facility-id) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get owner facility-data)) ERR-UNAUTHORIZED)
        (asserts! (> capacity u0) ERR-INVALID-PARAMS)
        (asserts! (> hourly-rate u0) ERR-INVALID-PARAMS)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
        (asserts! (<= (len name) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len description) u500) ERR-INVALID-PARAMS)
        (asserts! (<= (len location) u200) ERR-INVALID-PARAMS)
        (asserts! (validate-amenities amenities) ERR-INVALID-STRING)
        
        (map-set facilities
            { facility-id: facility-id }
            (merge facility-data
                {
                    name: name,
                    description: description,
                    location: location,
                    capacity: capacity,
                    hourly-rate: hourly-rate,
                    amenities: amenities,
                    updated-at: current-time
                }
            )
        )
        (ok true)
    )
)

(define-public (toggle-facility-status (facility-id uint))
    (let ((facility-data (unwrap! (get-facility facility-id) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get owner facility-data)) ERR-UNAUTHORIZED)
        
        (map-set facilities
            { facility-id: facility-id }
            (merge facility-data
                {
                    is-active: (not (get is-active facility-data)),
                    updated-at: current-time
                }
            )
        )
        (ok (not (get is-active facility-data)))
    )
)

;; User Management
(define-public (create-user-profile (name (string-ascii 100))
                                   (email (string-ascii 100))
                                   (phone (string-ascii 20)))
    (let ((current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-none (get-user-profile tx-sender)) ERR-ALREADY-EXISTS)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
        (asserts! (<= (len name) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len email) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len phone) u20) ERR-INVALID-PARAMS)
        (asserts! (is-valid-email email) ERR-INVALID-PARAMS)
        (asserts! (is-valid-phone phone) ERR-INVALID-PARAMS)
        
        (map-set user-profiles
            { user: tx-sender }
            {
                name: name,
                email: email,
                phone: phone,
                membership-level: "basic",
                total-bookings: u0,
                created-at: current-time,
                is-active: true
            }
        )
        (ok true)
    )
)

(define-public (update-user-profile (name (string-ascii 100))
                                   (email (string-ascii 100))
                                   (phone (string-ascii 20)))
    (let ((profile-data (unwrap! (get-user-profile tx-sender) ERR-NOT-FOUND)))
        (asserts! (get is-active profile-data) ERR-UNAUTHORIZED)
        (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
        (asserts! (<= (len name) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len email) u100) ERR-INVALID-PARAMS)
        (asserts! (<= (len phone) u20) ERR-INVALID-PARAMS)
        (asserts! (is-valid-email email) ERR-INVALID-PARAMS)
        (asserts! (is-valid-phone phone) ERR-INVALID-PARAMS)
        
        (map-set user-profiles
            { user: tx-sender }
            (merge profile-data
                {
                    name: name,
                    email: email,
                    phone: phone
                }
            )
        )
        (ok true)
    )
)

;; Booking Management
(define-public (create-booking (facility-id uint)
                              (start-time uint)
                              (duration-hours uint)
                              (special-requests (string-ascii 300)))
    (let ((facility-data (unwrap! (get-facility facility-id) ERR-NOT-FOUND))
          (end-time (+ start-time (* duration-hours u3600)))
          (booking-id (var-get next-booking-id))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
          (total-cost (unwrap! (calculate-booking-cost facility-id duration-hours) ERR-INVALID-PARAMS))
          (booking-date (get-date-from-timestamp start-time))
          (start-hour (get-hour-from-timestamp start-time)))
        
        (asserts! (get is-active facility-data) ERR-FACILITY-UNAVAILABLE)
        (asserts! (> start-time current-time) ERR-INVALID-TIME-SLOT)
        (asserts! (> duration-hours u0) ERR-INVALID-PARAMS)
        (asserts! (<= duration-hours u12) ERR-INVALID-PARAMS) ;; Max 12 hours
        (asserts! (<= (len special-requests) u300) ERR-INVALID-PARAMS)
        
        ;; Check availability for each hour (simplified single hour check for now)
        (asserts! (check-single-slot facility-id booking-date start-hour) ERR-BOOKING-CONFLICT)
        
        ;; Create booking record
        (map-set bookings
            { booking-id: booking-id }
            {
                facility-id: facility-id,
                user: tx-sender,
                start-time: start-time,
                end-time: end-time,
                total-cost: total-cost,
                status: "pending",
                payment-status: "pending",
                created-at: current-time,
                updated-at: current-time,
                special-requests: special-requests
            }
        )
        
        ;; Reserve the time slot (simplified single hour for now)
        (set-slot-status facility-id booking-date start-hour false (some booking-id))
        
        (var-set next-booking-id (+ booking-id u1))
        (ok booking-id)
    )
)

(define-public (pay-for-booking (booking-id uint))
    (let ((booking-data (unwrap! (get-booking booking-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get user booking-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get payment-status booking-data) "pending") ERR-INVALID-PARAMS)
        (asserts! (>= (stx-get-balance tx-sender) (get total-cost booking-data)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer payment (simplified - in production you'd handle this more carefully)
        (let ((facility-data (unwrap! (get-facility (get facility-id booking-data)) ERR-NOT-FOUND))
              (platform-fee (/ (* (get total-cost booking-data) (var-get platform-fee-rate)) u10000))
              (owner-payment (- (get total-cost booking-data) platform-fee)))
            
            ;; Transfer to facility owner
            (try! (stx-transfer? owner-payment tx-sender (get owner facility-data)))
            
            ;; Transfer platform fee to contract owner
            (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
            
            ;; Update booking status
            (map-set bookings
                { booking-id: booking-id }
                (merge booking-data
                    {
                        payment-status: "paid",
                        status: "confirmed",
                        updated-at: (unwrap-panic (get-block-info? time (- block-height u1)))
                    }
                )
            )
            
            ;; Update revenue statistics
            (update-revenue-stats (get facility-id booking-data) (get total-cost booking-data))
            
            ;; Update user profile
            (let ((user-profile (default-to 
                                    { name: "", email: "", phone: "", membership-level: "basic", 
                                      total-bookings: u0, created-at: u0, is-active: true }
                                    (get-user-profile tx-sender))))
                (map-set user-profiles
                    { user: tx-sender }
                    (merge user-profile
                        { total-bookings: (+ (get total-bookings user-profile) u1) }
                    )
                )
            )
            
            (ok true)
        )
    )
)

(define-public (cancel-booking (booking-id uint))
    (let ((booking-data (unwrap! (get-booking booking-id) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get user booking-data)) ERR-UNAUTHORIZED)
        (asserts! (or (is-eq (get status booking-data) "pending") 
                      (is-eq (get status booking-data) "confirmed")) ERR-INVALID-PARAMS)
        (asserts! (> (get start-time booking-data) (+ current-time u7200)) ERR-INVALID-PARAMS) ;; 2 hour minimum
        
        ;; Free up the time slot (simplified single hour)
        (let ((booking-date (get-date-from-timestamp (get start-time booking-data)))
              (start-hour (get-hour-from-timestamp (get start-time booking-data))))
            (set-slot-status (get facility-id booking-data) booking-date start-hour true none)
        )
        
        ;; Process refund if paid
        (if (is-eq (get payment-status booking-data) "paid")
            (let ((refund-amount (/ (* (get total-cost booking-data) u90) u100))) ;; 90% refund
                (try! (as-contract (stx-transfer? refund-amount tx-sender (get user booking-data))))
                (map-set bookings
                    { booking-id: booking-id }
                    (merge booking-data
                        {
                            status: "cancelled",
                            payment-status: "refunded",
                            updated-at: current-time
                        }
                    )
                )
            )
            (map-set bookings
                { booking-id: booking-id }
                (merge booking-data
                    {
                        status: "cancelled",
                        updated-at: current-time
                    }
                )
            )
        )
        (ok true)
    )
)

(define-public (check-in-booking (booking-id uint))
    (let ((booking-data (unwrap! (get-booking booking-id) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get user booking-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status booking-data) "confirmed") ERR-INVALID-PARAMS)
        (asserts! (>= current-time (- (get start-time booking-data) u1800)) ERR-INVALID-TIME-SLOT) ;; 30 min early
        (asserts! (<= current-time (+ (get start-time booking-data) u1800)) ERR-INVALID-TIME-SLOT) ;; 30 min late
        
        (map-set bookings
            { booking-id: booking-id }
            (merge booking-data
                {
                    status: "checked-in",
                    updated-at: current-time
                }
            )
        )
        (ok true)
    )
)

(define-public (complete-booking (booking-id uint))
    (let ((booking-data (unwrap! (get-booking booking-id) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get user booking-data)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status booking-data) "checked-in") ERR-INVALID-PARAMS)
        (asserts! (>= current-time (get end-time booking-data)) ERR-INVALID-TIME-SLOT)
        
        (map-set bookings
            { booking-id: booking-id }
            (merge booking-data
                {
                    status: "completed",
                    updated-at: current-time
                }
            )
        )
        (ok true)
    )
)

;; Maintenance Management
(define-public (schedule-maintenance (facility-id uint)
                                   (maintenance-type (string-ascii 50))
                                   (description (string-ascii 500))
                                   (scheduled-date uint)
                                   (cost uint))
    (let ((facility-data (unwrap! (get-facility facility-id) ERR-NOT-FOUND))
          (maintenance-id (var-get next-maintenance-id))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get owner facility-data)) ERR-UNAUTHORIZED)
        (asserts! (> scheduled-date current-time) ERR-INVALID-PARAMS)
        (asserts! (> (len description) u0) ERR-INVALID-PARAMS)
        (asserts! (<= (len description) u500) ERR-INVALID-PARAMS)
        (asserts! (is-valid-maintenance-type maintenance-type) ERR-INVALID-PARAMS)
        (asserts! (>= cost u0) ERR-INVALID-PARAMS) ;; Cost can be 0 for internal maintenance
        
        (map-set maintenance-records
            { maintenance-id: maintenance-id }
            {
                facility-id: facility-id,
                maintenance-type: maintenance-type,
                description: description,
                scheduled-date: scheduled-date,
                completion-date: none,
                cost: cost,
                status: "scheduled",
                assigned-to: none,
                created-by: tx-sender,
                created-at: current-time
            }
        )
        
        (var-set next-maintenance-id (+ maintenance-id u1))
        (ok maintenance-id)
    )
)

(define-public (update-maintenance-status (maintenance-id uint)
                                         (status (string-ascii 20))
                                         (assigned-to (optional principal)))
    (let ((maintenance-data (unwrap! (get-maintenance-record maintenance-id) ERR-NOT-FOUND))
          (facility-data (unwrap! (get-facility (get facility-id maintenance-data)) ERR-NOT-FOUND))
          (current-time (unwrap-panic (get-block-info? time (- block-height u1)))))
        (asserts! (is-eq tx-sender (get owner facility-data)) ERR-UNAUTHORIZED)
        (asserts! (> maintenance-id u0) ERR-INVALID-PARAMS) ;; Basic validation
        
        (map-set maintenance-records
            { maintenance-id: maintenance-id }
            (merge maintenance-data
                {
                    status: status,
                    assigned-to: assigned-to,
                    completion-date: (if (is-eq status "completed") (some current-time) (get completion-date maintenance-data))
                }
            )
        )
        (ok true)
    )
)

;; Admin functions
(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (<= new-rate u1000) ERR-INVALID-PARAMS) ;; Max 10%
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-public (approve-facility-owner (owner principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        ;; Validate the owner principal is not the zero address
        (asserts! (not (is-eq owner 'SP000000000000000000002Q6VF78)) ERR-INVALID-PARAMS)
        (let ((current-data (default-to { is-approved: false, facilities-count: u0 } 
                                       (map-get? facility-owners { owner: owner }))))
            (map-set facility-owners
                { owner: owner }
                (merge current-data { is-approved: true })
            )
        )
        (ok true)
    )
)