;; IPVault - Intellectual property registration and licensing platform

(define-non-fungible-token ip-patent uint)

;; Storage
(define-map patent-registry uint {inventor: principal, patent-title: (string-utf8 64), technology-field: (string-utf8 256), patent-description: (string-utf8 256), licensing-fee: uint})
(define-data-var patent-id-counter uint u0)

;; Error codes
(define-constant err-inventor-only (err u500))
(define-constant err-patent-not-found (err u501))
(define-constant err-licensing-failed (err u502))
(define-constant err-invalid-title (err u503))
(define-constant err-invalid-field (err u504))
(define-constant err-invalid-description (err u505))
(define-constant err-invalid-fee (err u506))
(define-constant err-invalid-patent-id (err u507))

;; Register patent
(define-public (register-patent (patent-title (string-utf8 64)) (technology-field (string-utf8 256)) (patent-description (string-utf8 256)) (licensing-fee uint))
  (begin
    ;; Validate patent parameters
    (asserts! (> (len patent-title) u0) err-invalid-title)
    (asserts! (> (len technology-field) u0) err-invalid-field)
    (asserts! (> (len patent-description) u0) err-invalid-description)
    (asserts! (> licensing-fee u0) err-invalid-fee)
    
    (let
      ((patent-id (var-get patent-id-counter))
       (inventor tx-sender))
      
      ;; Mint patent NFT
      (try! (nft-mint? ip-patent patent-id inventor))
      
      ;; Register patent details
      (map-set patent-registry patent-id {inventor: inventor, patent-title: patent-title, technology-field: technology-field, patent-description: patent-description, licensing-fee: licensing-fee})
      
      ;; Increment patent counter
      (var-set patent-id-counter (+ patent-id u1))
      
      (ok patent-id))))

;; License patent
(define-public (license-patent (patent-id uint))
  (begin
    ;; Validate patent ID
    (asserts! (< patent-id (var-get patent-id-counter)) err-invalid-patent-id)
    
    (let
      ((patent-data (unwrap! (map-get? patent-registry patent-id) err-patent-not-found))
       (fee (get licensing-fee patent-data))
       (inventor (get inventor patent-data))
       (current-owner (unwrap! (nft-get-owner? ip-patent patent-id) err-patent-not-found)))
      
      ;; Check licensee has sufficient funds
      (asserts! (>= (stx-get-balance tx-sender) fee) err-licensing-failed)
      
      ;; Transfer payment to inventor
      (try! (stx-transfer? fee tx-sender inventor))
      
      ;; Transfer patent license to licensee
      (try! (nft-transfer? ip-patent patent-id current-owner tx-sender))
      
      (ok true))))

;; Get patent details
(define-read-only (get-patent-details (patent-id uint))
  (map-get? patent-registry patent-id))

;; Check patent ownership
(define-read-only (owns-patent (patent-id uint) (holder principal))
  (is-eq (some holder) (nft-get-owner? ip-patent patent-id)))

;; Get patent owner
(define-read-only (get-patent-owner (patent-id uint))
  (nft-get-owner? ip-patent patent-id))