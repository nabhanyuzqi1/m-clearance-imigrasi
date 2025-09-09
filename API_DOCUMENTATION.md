# Firebase Functions API Documentation for Postman Testing

## Overview
This document provides comprehensive API documentation for testing Firebase Functions using Postman with Firebase Emulators. All functions are designed for the M-Clearance Immigration system.

## Emulator Setup
Before testing, ensure Firebase emulators are running:
```bash
# Start Functions emulator
cd functions && npm run serve

# Start RTDB emulator (in another terminal)
firebase emulators:start --only database
```

**Emulator URLs:**
- Functions: `http://127.0.0.1:5001`
- RTDB: `http://127.0.0.1:9000`
- Emulator UI: `http://127.0.0.1:4001`

## Authentication
Most functions require Firebase Authentication. For testing:
1. Create a test user in Firebase Auth emulator
2. Get the ID token
3. Include in headers: `Authorization: Bearer <token>`

---

## 1. Test Email Configuration
**Purpose:** Tests email configuration retrieval from RTDB and displays the config structure

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/testEmailConfig
Headers:
  Content-Type: application/json
Body: {}
```

### Postman Template
```json
{
  "info": {
    "name": "Test Email Configuration",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Test Email Config",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/testEmailConfig",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "testEmailConfig"]
        }
      }
    }
  ]
}
```

---

## 2. Issue Email Verification Code
**Purpose:** Generates and sends email verification code using configured templates

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/issueEmailVerificationCode
Headers:
  Content-Type: application/json
  Authorization: Bearer <firebase-auth-token>
Body: {}
```

### Postman Template
```json
{
  "info": {
    "name": "Issue Email Verification Code",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Send Verification Email",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{firebase_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/issueEmailVerificationCode",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "issueEmailVerificationCode"]
        }
      }
    }
  ]
}
```

---

## 3. Verify Email Code
**Purpose:** Verifies the submitted email verification code

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/verifyEmailCode
Headers:
  Content-Type: application/json
  Authorization: Bearer <firebase-auth-token>
Body:
{
  "code": "1234"
}
```

### Postman Template
```json
{
  "info": {
    "name": "Verify Email Code",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Verify Email Code",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{firebase_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"code\": \"1234\"\n}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/verifyEmailCode",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "verifyEmailCode"]
        }
      }
    }
  ]
}
```

---

## 4. Set User Role (Admin Only)
**Purpose:** Assigns role to a user (admin, officer, user)

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/setUserRole
Headers:
  Content-Type: application/json
  Authorization: Bearer <admin-firebase-auth-token>
Body:
{
  "uid": "user-uid-here",
  "role": "officer"
}
```

### Postman Template
```json
{
  "info": {
    "name": "Set User Role",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Set User Role",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{admin_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"uid\": \"user-uid-here\",\n  \"role\": \"officer\"\n}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/setUserRole",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "setUserRole"]
        }
      }
    }
  ]
}
```

---

## 5. Officer Decide Account
**Purpose:** Officer approves or rejects user account

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/officerDecideAccount
Headers:
  Content-Type: application/json
  Authorization: Bearer <officer-firebase-auth-token>
Body:
{
  "targetUid": "user-uid-here",
  "decision": "approved",
  "note": "Optional approval note"
}
```

### Postman Template
```json
{
  "info": {
    "name": "Officer Decide Account",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Approve/Reject Account",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{officer_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"targetUid\": \"user-uid-here\",\n  \"decision\": \"approved\",\n  \"note\": \"Optional approval note\"\n}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/officerDecideAccount",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "officerDecideAccount"]
        }
      }
    }
  ]
}
```

---

## 6. Get Officer Dashboard Stats
**Purpose:** Returns dashboard statistics for officers

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/getOfficerDashboardStats
Headers:
  Content-Type: application/json
  Authorization: Bearer <officer-firebase-auth-token>
Body: {}
```

### Postman Template
```json
{
  "info": {
    "name": "Get Officer Dashboard Stats",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Get Dashboard Stats",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{officer_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/getOfficerDashboardStats",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "getOfficerDashboardStats"]
        }
      }
    }
  ]
}
```

---

## 7. Initialize Counters
**Purpose:** Initializes dashboard counters

### Request
```
Method: POST
URL: http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/initializeCounters
Headers:
  Content-Type: application/json
  Authorization: Bearer <officer-firebase-auth-token>
Body: {}
```

### Postman Template
```json
{
  "info": {
    "name": "Initialize Counters",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Initialize Counters",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Authorization",
            "value": "Bearer {{officer_token}}"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{}"
        },
        "url": {
          "raw": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1/initializeCounters",
          "protocol": "http",
          "host": ["127", "0", "0", "1"],
          "port": "5001",
          "path": ["m-clearance-imigrasi", "us-central1", "initializeCounters"]
        }
      }
    }
  ]
}
```

---

## Complete Postman Collection
Here's a complete Postman collection JSON that includes all the above APIs:

```json
{
  "info": {
    "name": "M-Clearance Firebase Functions API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    "description": "Complete API collection for testing M-Clearance Firebase Functions with emulators"
  },
  "variable": [
    {
      "key": "base_url",
      "value": "http://127.0.0.1:5001/m-clearance-imigrasi/us-central1"
    },
    {
      "key": "firebase_token",
      "value": "your-firebase-auth-token-here"
    },
    {
      "key": "admin_token",
      "value": "your-admin-firebase-auth-token-here"
    },
    {
      "key": "officer_token",
      "value": "your-officer-firebase-auth-token-here"
    }
  ],
  "item": [
    {
      "name": "Email Configuration",
      "item": [
        {
          "name": "Test Email Configuration",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{}"
            },
            "url": {
              "raw": "{{base_url}}/testEmailConfig",
              "host": ["{{base_url}}"],
              "path": ["testEmailConfig"]
            }
          }
        }
      ]
    },
    {
      "name": "Authentication",
      "item": [
        {
          "name": "Issue Email Verification Code",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{firebase_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{}"
            },
            "url": {
              "raw": "{{base_url}}/issueEmailVerificationCode",
              "host": ["{{base_url}}"],
              "path": ["issueEmailVerificationCode"]
            }
          }
        },
        {
          "name": "Verify Email Code",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{firebase_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"code\": \"1234\"\n}"
            },
            "url": {
              "raw": "{{base_url}}/verifyEmailCode",
              "host": ["{{base_url}}"],
              "path": ["verifyEmailCode"]
            }
          }
        }
      ]
    },
    {
      "name": "Admin Functions",
      "item": [
        {
          "name": "Set User Role",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{admin_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"uid\": \"user-uid-here\",\n  \"role\": \"officer\"\n}"
            },
            "url": {
              "raw": "{{base_url}}/setUserRole",
              "host": ["{{base_url}}"],
              "path": ["setUserRole"]
            }
          }
        }
      ]
    },
    {
      "name": "Officer Functions",
      "item": [
        {
          "name": "Officer Decide Account",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{officer_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{\n  \"targetUid\": \"user-uid-here\",\n  \"decision\": \"approved\",\n  \"note\": \"Optional approval note\"\n}"
            },
            "url": {
              "raw": "{{base_url}}/officerDecideAccount",
              "host": ["{{base_url}}"],
              "path": ["officerDecideAccount"]
            }
          }
        },
        {
          "name": "Get Officer Dashboard Stats",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{officer_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{}"
            },
            "url": {
              "raw": "{{base_url}}/getOfficerDashboardStats",
              "host": ["{{base_url}}"],
              "path": ["getOfficerDashboardStats"]
            }
          }
        },
        {
          "name": "Initialize Counters",
          "request": {
            "method": "POST",
            "header": [
              {
                "key": "Content-Type",
                "value": "application/json"
              },
              {
                "key": "Authorization",
                "value": "Bearer {{officer_token}}"
              }
            ],
            "body": {
              "mode": "raw",
              "raw": "{}"
            },
            "url": {
              "raw": "{{base_url}}/initializeCounters",
              "host": ["{{base_url}}"],
              "path": ["initializeCounters"]
            }
          }
        }
      ]
    }
  ]
}
```

## Testing Steps

1. **Import the collection** into Postman
2. **Set environment variables** for tokens:
   - `firebase_token`: Your Firebase Auth token
   - `admin_token`: Admin Firebase Auth token
   - `officer_token`: Officer Firebase Auth token
3. **Start Firebase emulators** as described above
4. **Test the functions** in order:
   - Start with `Test Email Configuration` to verify setup
   - Test email functions with proper authentication
   - Test admin/officer functions with appropriate tokens

## Email Template Testing

The email functionality has been fixed to properly use template IDs from RTDB configuration:

- **RTDB Configuration**: Templates configured via the email config screen
- **Fallback**: Environment variables when RTDB is not available
- **Template Usage**: Functions now correctly retrieve and use template IDs
- **Personalization**: Emails include proper template variables (code, name, etc.)

## Notes

- All functions include proper error handling and logging
- Authentication is required for most functions
- The `testEmailConfig` function is particularly useful for debugging email configuration
- Template IDs are retrieved from RTDB with fallback to environment variables
- Email sending uses MailerSend extension with proper template support