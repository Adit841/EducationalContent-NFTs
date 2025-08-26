
(define-non-fungible-token edu-content-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-token-not-found (err u103))
(define-constant err-insufficient-payment (err u104))
(define-constant err-invalid-royalty (err u105))

;; Data Variables
(define-data-var last-token-id uint u0)

;; Data Maps
;; Store educational content metadata
(define-map content-metadata uint {
  title: (string-ascii 100),
  creator: principal,
  content-hash: (string-ascii 64),
  price: uint,
  royalty-percent: uint,
  category: (string-ascii 50)
})

;; Store creator royalty information
(define-map creator-royalties principal uint)

;; Function 1: Mint Educational Content NFT
;; Allows creators to mint NFTs for their educational materials
(define-public (mint-edu-content 
    (title (string-ascii 100))
    (content-hash (string-ascii 64))
    (price uint)
    (royalty-percent uint)
    (category (string-ascii 50))
    (recipient principal))
  (let 
    ((token-id (+ (var-get last-token-id) u1)))
    (begin
      ;; Validate royalty percentage (max 25%)
      (asserts! (<= royalty-percent u25) err-invalid-royalty)
      
      ;; Mint the NFT
      (try! (nft-mint? edu-content-nft token-id recipient))
      
      ;; Store content metadata
      (map-set content-metadata token-id {
        title: title,
        creator: tx-sender,
        content-hash: content-hash,
        price: price,
        royalty-percent: royalty-percent,
        category: category
      })
      
      ;; Update last token ID
      (var-set last-token-id token-id)
      
      ;; Initialize creator royalties tracking
      (map-set creator-royalties tx-sender u0)
      
      (ok token-id))))

;; Function 2: Purchase Educational Content
;; Allows students to purchase educational content NFTs with automatic royalty distribution
(define-public (purchase-content (token-id uint) (payment uint))
  (let 
    ((content-info (unwrap! (map-get? content-metadata token-id) err-token-not-found))
     (current-owner (unwrap! (nft-get-owner? edu-content-nft token-id) err-token-not-found))
     (creator (get creator content-info))
     (price (get price content-info))
     (royalty-percent (get royalty-percent content-info))
     (royalty-amount (/ (* price royalty-percent) u100))
     (seller-amount (- price royalty-amount)))
    (begin
      ;; Check if payment is sufficient
      (asserts! (>= payment price) err-insufficient-payment)
      
      ;; Transfer payment to current owner (minus royalty)
      (try! (stx-transfer? seller-amount tx-sender current-owner))
      
      ;; Transfer royalty to creator (if different from current owner)
      (if (not (is-eq creator current-owner))
        (begin
          (try! (stx-transfer? royalty-amount tx-sender creator))
          ;; Update creator royalties tracking
          (map-set creator-royalties creator 
            (+ (default-to u0 (map-get? creator-royalties creator)) royalty-amount)))
        true)
      
      ;; Transfer NFT to buyer
      (try! (nft-transfer? edu-content-nft token-id current-owner tx-sender))
      
      (ok true))))

;; Read-only functions for querying data

;; Get content metadata
(define-read-only (get-content-info (token-id uint))
  (map-get? content-metadata token-id))

;; Get NFT owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? edu-content-nft token-id)))

;; Get creator total royalties earned
(define-read-only (get-creator-royalties (creator principal))
  (ok (default-to u0 (map-get? creator-royalties creator))))

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))
