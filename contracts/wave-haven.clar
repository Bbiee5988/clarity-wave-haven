;; WaveHaven Main Contract

(define-map sessions
  { id: uint }
  {
    creator: principal,
    title: (string-utf8 64),
    description: (string-utf8 256),
    price: uint,
    frequency: uint,
    duration: uint,
    rating: uint,
    reviews: uint,
    active: bool,
    paused: bool,
    created-at: uint
  }
)

(define-map user-sessions
  { user: principal }
  { 
    owned-sessions: (list 100 uint),
    purchase-times: (list 100 uint)
  }
)

(define-map session-ratings
  { session-id: uint, user: principal }
  { 
    rating: uint, 
    reviewed: bool,
    comment: (optional (string-utf8 256)),
    timestamp: uint
  }
)

(define-data-var session-counter uint u0)
(define-data-var contract-paused bool false)
(define-constant refund-window uint u86400) ;; 24 hours in seconds

;; Error constants
(define-constant err-invalid-session (err u102))
(define-constant err-already-purchased (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-invalid-rating (err u105))
(define-constant err-contract-paused (err u106))
(define-constant err-already-rated (err u107))
(define-constant err-refund-expired (err u108))
(define-constant err-session-paused (err u109))

;; Admin functions
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (ok (var-set contract-paused (not (var-get contract-paused))))
  )
)

(define-public (toggle-session-pause (session-id uint))
  (let ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session)))
    (asserts! (is-eq tx-sender (get creator session)) (err u104))
    (ok (map-set sessions
      { id: session-id }
      (merge session { paused: (not (get paused session)) })))
  )
)

(define-public (create-session (title (string-utf8 64)) (description (string-utf8 256)) (price uint) (frequency uint) (duration uint))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (> price u0) (err u107))
    (asserts! (> frequency u0) (err u108))
    (asserts! (> duration u0) (err u109))
    
    (let
      ((session-id (+ (var-get session-counter) u1)))
      (map-set sessions
        { id: session-id }
        {
          creator: tx-sender,
          title: title,
          description: description,
          price: price,
          frequency: frequency,
          duration: duration,
          rating: u0,
          reviews: u0,
          active: true,
          paused: false,
          created-at: block-height
        }
      )
      (var-set session-counter session-id)
      (print { event: "session-created", session-id: session-id, creator: tx-sender })
      (ok session-id)
    )
  )
)

(define-public (purchase-session (session-id uint))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (let
      ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session))
       (current-owned (default-to { owned-sessions: (list), purchase-times: (list) } 
                      (map-get? user-sessions { user: tx-sender }))))
      
      (asserts! (get active session) (err u110))
      (asserts! (not (get paused session)) err-session-paused)
      (try! (contract-call? .wave-token transfer (get price session) (get creator session)))
      
      (map-set user-sessions
        { user: tx-sender }
        { 
          owned-sessions: (append (get owned-sessions current-owned) session-id),
          purchase-times: (append (get purchase-times current-owned) block-height)
        }
      )
      
      (print { event: "session-purchased", session-id: session-id, buyer: tx-sender })
      (ok true)
    )
  )
)

(define-public (request-refund (session-id uint))
  (let
    ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session))
     (user-data (unwrap! (map-get? user-sessions { user: tx-sender }) err-not-owner))
     (purchase-index (unwrap! (index-of (get owned-sessions user-data) session-id) err-not-owner))
     (purchase-time (unwrap! (element-at (get purchase-times user-data) purchase-index) err-not-owner)))
    
    (asserts! (<= (- block-height purchase-time) refund-window) err-refund-expired)
    (try! (contract-call? .wave-token transfer (get price session) tx-sender))
    
    (ok true)
  )
)

(define-public (rate-session (session-id uint) (rating uint) (comment (optional (string-utf8 256))))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (<= rating u5) err-invalid-rating)
    (asserts! (> rating u0) err-invalid-rating)
    
    (let
      ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session))
       (ownership (default-to { owned-sessions: (list) } (map-get? user-sessions { user: tx-sender })))
       (existing-rating (map-get? session-ratings { session-id: session-id, user: tx-sender })))
      
      (asserts! (is-some (index-of (get owned-sessions ownership) session-id)) err-not-owner)
      (asserts! (is-none existing-rating) err-already-rated)
      
      (map-set session-ratings
        { session-id: session-id, user: tx-sender }
        { 
          rating: rating, 
          reviewed: true,
          comment: comment,
          timestamp: block-height
        }
      )
      
      (map-set sessions
        { id: session-id }
        (merge session {
          rating: (/ (+ (* (get rating session) (get reviews session)) rating)
                    (+ (get reviews session) u1)),
          reviews: (+ (get reviews session) u1)
        })
      )
      
      (print { event: "session-rated", session-id: session-id, user: tx-sender, rating: rating })
      (ok true)
    )
  )
)

(define-read-only (get-session (id uint))
  (map-get? sessions { id: id })
)

(define-read-only (get-user-sessions (user principal))
  (map-get? user-sessions { user: user })
)

(define-read-only (get-session-rating (session-id uint) (user principal))
  (map-get? session-ratings { session-id: session-id, user: user })
)
