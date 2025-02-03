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
    reviews: uint
  }
)

(define-map user-sessions
  { user: principal }
  { owned-sessions: (list 100 uint) }
)

(define-data-var session-counter uint u0)

(define-constant err-invalid-session (err u102))
(define-constant err-already-purchased (err u103))

(define-public (create-session (title (string-utf8 64)) (description (string-utf8 256)) (price uint) (frequency uint) (duration uint))
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
        reviews: u0
      }
    )
    (var-set session-counter session-id)
    (ok session-id)
  )
)

(define-public (purchase-session (session-id uint))
  (let
    ((session (unwrap! (map-get? sessions { id: session-id }) err-invalid-session))
     (wave-token (contract-call? .wave-token transfer (get price session) (get creator session))))
    (asserts! (is-ok wave-token) (err u104))
    (ok true)
  )
)

(define-read-only (get-session (id uint))
  (map-get? sessions { id: id })
)
