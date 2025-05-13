;; Prisma Catalogue

;; Primary Asset Registry
(define-map vault-registry
  { asset-id: uint } ;; Unique asset identifier
  {
    title: (string-ascii 64),            ;; Asset title/name 
    creator: principal,                  ;; Principal who created the asset
    byte-volume: uint,                   ;; Storage space required
    creation-block: uint,                ;; Block when asset was registered
    group-classification: (string-ascii 32), ;; Organization category
    description: (string-ascii 128),     ;; Descriptive metadata
    feature-labels: (list 10 (string-ascii 32)) ;; Classification tags
  }
)


;; Global Vault Statistics and Storage
(define-data-var vault-asset-counter uint u0) ;; Tracks total assets in the vault


;; Response Codes
(define-constant RESPONSE_NOT_FOUND (err u401)) ;; Asset could not be located in the vault
(define-constant RESPONSE_INVALID_DIMENSIONS (err u404)) ;; Asset dimensions validation failed
(define-constant RESPONSE_DUPLICATE_ENTRY (err u402)) ;; Attempting to store duplicate asset
(define-constant RESPONSE_INVALID_TITLE (err u403)) ;; Asset title validation failed
(define-constant RESPONSE_PERMISSION_VIOLATION (err u408)) ;; Access controls violated
(define-constant RESPONSE_INVALID_SHARING_REQUEST (err u409)) ;; Invalid sharing parameters
(define-constant RESPONSE_INVALID_USER_ADDRESS (err u410)) ;; User address validation failed
(define-constant RESPONSE_NOT_PERMITTED (err u405)) ;; Operation requires higher permissions
(define-constant RESPONSE_INVALID_GROUP (err u406)) ;; Group validation failed
(define-constant RESPONSE_OPERATION_BLOCKED (err u407)) ;; Operation not allowed for security reasons
(define-constant RESPONSE_ALREADY_BOOKMARKED (err u411)) ;; Asset is already bookmarked
(define-constant RESPONSE_NOT_BOOKMARKED (err u412)) ;; Asset is not in bookmarks

;; Administrative Configuration
(define-constant VAULT_ADMINISTRATOR tx-sender) ;; System administrator with elevated privileges

;; Access Control Management
(define-map permission-registry
  { asset-id: uint, viewer: principal } ;; Compound key: asset and user
  { 
    permission-granted: bool,          ;; Whether access is permitted
    permission-source: principal,      ;; Who granted the permission
    permission-timestamp: uint         ;; When permission was last modified
  }
)

;; User Bookmark System
(define-map user-bookmarks
  { user-address: principal, asset-id: uint }  ;; Compound key: user and asset
  {
    timestamp-added: uint,             ;; When bookmark was created
    timestamp-modified: uint           ;; When bookmark was last modified
  }
)


;; INTERNAL UTILITY FUNCTIONS


;; Verify asset exists in the vault
(define-private (asset-exists? (asset-id uint))
  (is-some (map-get? vault-registry { asset-id: asset-id }))
)

;; Verify the requesting user is the creator of the asset
(define-private (validate-creator-rights? (asset-id uint) (requester principal))
  (match (map-get? vault-registry { asset-id: asset-id })
    vault-entry (is-eq (get creator vault-entry) requester)
    false
  )
)

;; Validate principal is not a burn address
(define-private (valid-principal? (user-principal principal))
  (not (is-eq user-principal 'ST000000000000000000002AMW42H))
)

;; Check if user has viewing permissions for an asset
(define-private (has-view-permission? (asset-id uint) (viewer principal))
  (match (map-get? permission-registry { asset-id: asset-id, viewer: viewer })
    permission-data (get permission-granted permission-data)
    false
  )
)

;; Check if an asset is bookmarked by a user
(define-private (is-bookmarked? (asset-id uint) (user-address principal))
  (is-some (map-get? user-bookmarks { user-address: user-address, asset-id: asset-id }))
)

;; Get the storage size of an asset
(define-private (get-asset-size (asset-id uint))
  (default-to u0 
    (get byte-volume 
      (map-get? vault-registry { asset-id: asset-id })
    )
  )
)


;; FEATURE LABEL VALIDATION


;; Validate individual feature label
(define-private (validate-feature-label (label (string-ascii 32)))
  (and 
    (> (len label) u0)
    (< (len label) u33)
  )
)

;; Validate collection of feature labels
(define-private (validate-feature-collection (labels (list 10 (string-ascii 32))))
  (and
    (> (len labels) u0)
    (<= (len labels) u10)
    (is-eq (len (filter validate-feature-label labels)) (len labels))
  )
)


;; PUBLIC INTERFACE FUNCTIONS

;; Register a new asset in the vault
(define-public (register-asset (title (string-ascii 64)) (byte-volume uint) (group-classification (string-ascii 32)) (description (string-ascii 128)) (feature-labels (list 10 (string-ascii 32))))
  (let
    (
      (new-asset-id (+ (var-get vault-asset-counter) u1))
    )
    ;; Input validation
    (asserts! (> (len title) u0) RESPONSE_INVALID_TITLE)
    (asserts! (< (len title) u65) RESPONSE_INVALID_TITLE)
    (asserts! (> byte-volume u0) RESPONSE_INVALID_DIMENSIONS)
    (asserts! (< byte-volume u1000000000) RESPONSE_INVALID_DIMENSIONS)
    (asserts! (> (len group-classification) u0) RESPONSE_INVALID_GROUP)
    (asserts! (< (len group-classification) u33) RESPONSE_INVALID_GROUP)
    (asserts! (> (len description) u0) RESPONSE_INVALID_TITLE)
    (asserts! (< (len description) u129) RESPONSE_INVALID_TITLE)
    (asserts! (validate-feature-collection feature-labels) RESPONSE_INVALID_TITLE)

    ;; Record asset in vault
    (map-insert vault-registry
      { asset-id: new-asset-id }
      {
        title: title,
        creator: tx-sender,
        byte-volume: byte-volume, 
        creation-block: block-height,
        group-classification: group-classification,
        description: description,
        feature-labels: feature-labels
      }
    )

    ;; Automatically grant access to creator
    (map-insert permission-registry
      { asset-id: new-asset-id, viewer: tx-sender }
      { 
        permission-granted: true,
        permission-source: tx-sender,
        permission-timestamp: block-height
      }
    )
    (var-set vault-asset-counter new-asset-id) ;; Increment asset counter
    (ok new-asset-id)
  )
)

;; Bookmark an asset for quick access
(define-public (bookmark-asset (asset-id uint))
  (let
    (
      (vault-entry (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate asset exists and user has access
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (has-view-permission? asset-id tx-sender) RESPONSE_PERMISSION_VIOLATION)
    (asserts! (not (is-bookmarked? asset-id tx-sender)) RESPONSE_ALREADY_BOOKMARKED)

    ;; Add to bookmarks
    (map-insert user-bookmarks
      { user-address: tx-sender, asset-id: asset-id }
      {
        timestamp-added: block-height,
        timestamp-modified: block-height
      }
    )
    (ok true)
  )
)

;; Remove asset from bookmarks
(define-public (remove-bookmark (asset-id uint))
  (let
    (
      (vault-entry (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate asset exists and is bookmarked
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (is-bookmarked? asset-id tx-sender) RESPONSE_NOT_BOOKMARKED)

    ;; Remove from bookmarks
    (map-delete user-bookmarks { user-address: tx-sender, asset-id: asset-id })
    (ok true)
  )
)

;; Check bookmark status for an asset
(define-read-only (check-bookmark-status (asset-id uint))
  (ok (is-bookmarked? asset-id tx-sender))
)

;; Share asset with another user
(define-public (share-asset (asset-id uint) (recipient principal))
  (let
    (
      (vault-entry (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate asset existence and ownership
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (validate-creator-rights? asset-id tx-sender) RESPONSE_NOT_PERMITTED)
    (asserts! (not (is-eq recipient tx-sender)) RESPONSE_INVALID_SHARING_REQUEST)

    ;; Grant access permissions
    (map-set permission-registry
      { asset-id: asset-id, viewer: recipient }
      { 
        permission-granted: true,
        permission-source: tx-sender,
        permission-timestamp: block-height
      }
    )
    (ok true)
  )
)

;; Revoke access to an asset
(define-public (revoke-access (asset-id uint) (viewer principal))
  (let
    (
      (vault-entry (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
      (permission-data (unwrap! (map-get? permission-registry { asset-id: asset-id, viewer: viewer }) RESPONSE_NOT_PERMITTED))
    )
    ;; Validate asset existence and ownership
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (validate-creator-rights? asset-id tx-sender) RESPONSE_NOT_PERMITTED)
    (asserts! (not (is-eq viewer tx-sender)) RESPONSE_INVALID_SHARING_REQUEST)

    ;; Remove access permissions
    (map-delete permission-registry { asset-id: asset-id, viewer: viewer })
    ;; Also remove any bookmarks if they exist
    (if (is-bookmarked? asset-id viewer)
      (map-delete user-bookmarks { user-address: viewer, asset-id: asset-id })
      true
    )
    (ok true)
  )
)

;; Check if user has access to an asset
(define-read-only (verify-access (asset-id uint) (viewer principal))
  (ok (has-view-permission? asset-id viewer))
)

;; Transfer asset ownership
(define-public (transfer-asset (asset-id uint) (new-creator principal))
  (let
    (
      (asset-details (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate ownership, asset existence, and new owner
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (validate-creator-rights? asset-id tx-sender) RESPONSE_NOT_PERMITTED)
    (asserts! (not (is-eq new-creator tx-sender)) RESPONSE_INVALID_SHARING_REQUEST)
    (asserts! (valid-principal? new-creator) RESPONSE_INVALID_USER_ADDRESS)

    ;; Update ownership
    (map-set vault-registry
      { asset-id: asset-id }
      (merge asset-details { creator: new-creator })
    )

    ;; Transfer access permissions to new owner
    (map-set permission-registry
      { asset-id: asset-id, viewer: new-creator }
      {
        permission-granted: true,
        permission-source: tx-sender,
        permission-timestamp: block-height
      }
    )
    (ok true)
  )
)

;; Update asset metadata
(define-public (update-asset (asset-id uint) (updated-title (string-ascii 64)) (updated-byte-volume uint) (updated-group-classification (string-ascii 32)) (updated-description (string-ascii 128)) (updated-feature-labels (list 10 (string-ascii 32))))
  (let
    (
      (asset-details (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate ownership and inputs
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (is-eq (get creator asset-details) tx-sender) RESPONSE_NOT_PERMITTED)
    (asserts! (> (len updated-title) u0) RESPONSE_INVALID_TITLE)
    (asserts! (< (len updated-title) u65) RESPONSE_INVALID_TITLE)
    (asserts! (> updated-byte-volume u0) RESPONSE_INVALID_DIMENSIONS)
    (asserts! (< updated-byte-volume u1000000000) RESPONSE_INVALID_DIMENSIONS)
    (asserts! (> (len updated-group-classification) u0) RESPONSE_INVALID_GROUP)
    (asserts! (< (len updated-group-classification) u33) RESPONSE_INVALID_GROUP)
    (asserts! (> (len updated-description) u0) RESPONSE_INVALID_TITLE)
    (asserts! (< (len updated-description) u129) RESPONSE_INVALID_TITLE)
    (asserts! (validate-feature-collection updated-feature-labels) RESPONSE_INVALID_TITLE)

    ;; Update asset metadata
    (map-set vault-registry
      { asset-id: asset-id }
      (merge asset-details { 
        title: updated-title, 
        byte-volume: updated-byte-volume, 
        group-classification: updated-group-classification, 
        description: updated-description, 
        feature-labels: updated-feature-labels 
      })
    )
    (ok true)
  )
)

;; Remove asset from vault
(define-public (purge-asset (asset-id uint))
  (let
    (
      (asset-details (unwrap! (map-get? vault-registry { asset-id: asset-id }) RESPONSE_NOT_FOUND))
    )
    ;; Validate ownership and existence
    (asserts! (asset-exists? asset-id) RESPONSE_NOT_FOUND)
    (asserts! (is-eq (get creator asset-details) tx-sender) RESPONSE_NOT_PERMITTED)

    ;; Remove asset from vault
    (map-delete vault-registry { asset-id: asset-id })
    (ok true)
  )
)

