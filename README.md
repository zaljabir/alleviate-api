# Alleviate Health API

A simple API server for updating phone numbers in website settings.

## Features

- 🏥 Health check endpoint
- 📱 Phone number update endpoint
- 🚀 Express.js server with CORS support
- 🎭 Playwright integration ready for implementation

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Install Playwright browsers:**
   ```bash
   npx playwright install chromium
   ```

3. **Start the server:**
   ```bash
   npm start
   ```
   
   Or for development with auto-reload:
   ```bash
   npm run dev
   ```

The server will start on `http://localhost:3000`

## API Documentation

Interactive API documentation is available at:
- **Swagger UI**: `http://localhost:3000/api-docs`

The Swagger documentation includes:
- 📋 Complete API reference
- 🔐 Authentication details (Basic Auth)
- 📝 Request/response examples
- 🧪 Interactive testing interface

## API Endpoints

### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "OK",
  "message": "Alleviate Health API is running",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### Update Phone Number
```http
POST /settings/phone
Content-Type: application/json
Authorization: Basic <base64-encoded-credentials>

{
  "phoneNumber": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Phone number update initiated",
  "data": {
    "phoneNumber": "+1234567890",
    "websiteUrl": "https://example.com",
    "status": "pending"
  },
  "updatedAt": "2024-01-01T00:00:00.000Z"
}
```

**Error Response (Missing phone number):**
```json
{
  "error": "Phone number is required",
  "example": {
    "phoneNumber": "+1234567890"
  }
}
```

**Error Response (Missing Basic Auth):**
```json
{
  "error": "Basic Authentication required",
  "example": "Authorization: Basic <base64-encoded-credentials>"
}
```

## Example Usage

### Using curl

```bash
# Health check
curl http://localhost:3000/health

# Update phone number (replace username:password with your credentials)
curl -X POST http://localhost:3000/settings/phone \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -d '{"phoneNumber": "+1234567890"}'
```

### Using JavaScript/Fetch

```javascript
// Update phone number
const response = await fetch('http://localhost:3000/settings/phone', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Basic ' + Buffer.from('username:password').toString('base64')
  },
  body: JSON.stringify({
    phoneNumber: '+1234567890'
  })
});

const data = await response.json();
console.log(data);
```

## Environment Variables

Create a `.env` file in the root directory:

```
PORT=3000
NODE_ENV=development
```

## Error Handling

All endpoints return appropriate HTTP status codes and error messages:

- `400` - Bad Request (missing required parameters)
- `404` - Not Found (invalid endpoint)
- `500` - Internal Server Error (Playwright or server errors)

## Dependencies

- **express** - Web framework
- **cors** - Cross-origin resource sharing
- **playwright** - Browser automation
- **dotenv** - Environment variable management
- **swagger-ui-express** - Swagger UI for API documentation
- **swagger-jsdoc** - Generate Swagger documentation from JSDoc comments
- **node-fetch** - HTTP client for testing
- **nodemon** - Development auto-reload (dev dependency)

## 🚀 Deployment

This project includes automated deployment scripts for AWS EC2 Spot instances. See the [`deployment/`](./deployment/) folder for:

- **Deployment scripts** - Automated AWS deployment
- **Update scripts** - Deploy code changes
- **Cleanup scripts** - Remove AWS resources
- **Documentation** - Complete deployment guides

### Quick Deployment

```bash
# Deploy to AWS (run from project root)
./deployment/deploy-spot-instance.sh

# Update existing deployment
./deployment/update-deployment.sh

# Clean up resources
./deployment/cleanup-spot-instance.sh
```

For detailed deployment instructions, see [`deployment/README.md`](./deployment/README.md).

## License

MIT
