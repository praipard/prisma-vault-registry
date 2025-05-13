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

