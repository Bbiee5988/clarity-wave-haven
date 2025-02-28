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
    active: bool
  }
)

(define-map user-sessions
  { user: principal }
  { owned-sessions: (list 100 uint) }
)

(define-map session-ratings
  { session-id: uint, user: principal }
  { rating: uint, reviewed: bool }
)

(define-data-var session-counter uint u0)
(define-data-var contract-paused bool false)

;; Error constants
(define-constant err-invalid-session (err u102))
(define-constant err-already-purchased (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-invalid-rating (err u105))
(define-constant err-contract-paused (err u106))

;; Admin functions
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (ok (var-set contract-paused (not (var-get contract-paused))))
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
          active: true
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
       (current-owned (default-to { owned-sessions: (list) } (map-get? user-sessions { user: tx-sender }))))
      
      (asserts! (get active session) (err u110))
      (try! (contract-call? .wave-token transfer (get price session) (get creator session)))
      
      (map-set user-sessions
        { user: tx-sender }
        { owned-sessions: (append (get owned-sessions current-owned) session-id) }
      )
      
      (print { event: "session-purchased", session-id: session-id, buyer: tx-sender })
      (ok true)
    )
  )
)

(define-public (rate-session (session-id uint) (rating uint))
  (begin
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (<= rating u5) err-invalid-rating)
    (asserts! (> rating u0) err-invalid-rating)
    
    (let
      ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session))
       (ownership (default-to { owned-sessions: (list) } (map-get? user-sessions { user: tx-sender }))))
      
      (asserts! (is-some (index-of (get owned-sessions ownership) session-id)) err-not-owner)
      
      (map-set session-ratings
        { session-id: session-id, user: tx-sender }
        { rating: rating, reviewed: true }
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

(define-read-only (has-purchased (user principal) (session-id uint))
  (let
    ((ownership (default-to { owned-sessions: (list) } (map-get? user-sessions { user: user }))))
    (is-some (index-of (get owned-sessions ownership) session-id))
  )
)
