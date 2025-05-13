# Prisma Vault Registry

The **Prisma Vault Registry** is a Clarity-based smart contract that enables decentralized asset registration, ownership validation, access permission management, sharing, metadata updates, and secure bookmarking in the Stacks blockchain ecosystem.

## 🛠 Features

- **Asset Registration**: On-chain creation of uniquely identified assets with metadata.
- **Access Control**: Grant, verify, and revoke viewer permissions.
- **Ownership Transfer**: Securely transfer asset ownership.
- **Asset Sharing**: Share access with other principals.
- **Bookmarking System**: Track user-specific bookmarks for fast lookup.
- **Secure Validation**: Internal checks for ownership, sharing conditions, and valid principal addresses.
- **Metadata Management**: Update titles, storage size, tags, and descriptions.
- **Deletion/Purging**: Safely remove asset records.

## 📚 Contract Structure

### Maps
- `vault-registry`: Asset metadata and registry
- `permission-registry`: Viewer access control
- `user-bookmarks`: Personal bookmarks per user

### Data Variables
- `vault-asset-counter`: Total number of assets registered

### Key Constants
Defined error codes (e.g., `RESPONSE_NOT_FOUND`, `RESPONSE_INVALID_GROUP`) and admin identity.

## 📜 Public Functions
- `register-asset`
- `bookmark-asset`
- `remove-bookmark`
- `check-bookmark-status`
- `share-asset`
- `revoke-access`
- `verify-access`
- `transfer-asset`
- `update-asset`
- `purge-asset`

## 🔒 Security Considerations
- Burn address rejection
- Creator-based access enforcement
- Share/revoke guards to prevent misuse
- Bookmarking limited to authorized viewers

## ✅ Deployment
Compatible with the Stacks 2.1 network. Can be deployed using Clarinet or directly via Stacks CLI.

## 📄 License
MIT License
