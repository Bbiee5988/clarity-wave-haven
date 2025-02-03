(define-fungible-token wave)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? wave amount recipient)
  )
)

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? wave amount tx-sender recipient)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance wave account))
)
