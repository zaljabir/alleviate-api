const express = require('express');
const cors = require('cors');
const { chromium } = require('playwright');
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Alleviate Health API',
      version: '1.0.0',
      description: 'API for updating phone numbers in website settings using Playwright automation',
      contact: {
        name: 'API Support',
        email: 'support@alleviatehealth.care'
      }
    },
    servers: [
      {
        url: `http://localhost:${PORT}`,
        description: 'Development server'
      }
    ],
    components: {
      securitySchemes: {
        BasicAuth: {
          type: 'http',
          scheme: 'basic',
          description: 'Basic authentication using username and password'
        }
      },
      schemas: {
        PhoneUpdateRequest: {
          type: 'object',
          required: ['phoneNumber'],
          properties: {
            phoneNumber: {
              type: 'string',
              description: 'Phone number to update in the format +1234567890',
              example: '+1234567890'
            }
          }
        },
        SuccessResponse: {
          type: 'object',
          properties: {
            success: {
              type: 'boolean',
              example: true
            },
            message: {
              type: 'string',
              example: 'Phone number updated successfully'
            },
            data: {
              type: 'object',
              properties: {
                phoneNumber: {
                  type: 'string',
                  example: '+1234567890'
                },
                status: {
                  type: 'string',
                  example: 'completed'
                }
              }
            },
            updatedAt: {
              type: 'string',
              format: 'date-time',
              example: '2024-01-01T00:00:00.000Z'
            }
          }
        },
        ErrorResponse: {
          type: 'object',
          properties: {
            error: {
              type: 'string',
              example: 'Phone number is required'
            },
            example: {
              type: 'object',
              properties: {
                phoneNumber: {
                  type: 'string',
                  example: '+1234567890'
                }
              }
            }
          }
        },
        HealthResponse: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              example: 'OK'
            },
            message: {
              type: 'string',
              example: 'Alleviate Health API is running'
            },
            timestamp: {
              type: 'string',
              format: 'date-time',
              example: '2024-01-01T00:00:00.000Z'
            }
          }
        }
      }
    },
    security: [
      {
        BasicAuth: []
      }
    ]
  },
  apis: ['./server.js'] // Path to the API files
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

// Serve Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'Alleviate Health API Documentation'
}));

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check endpoint
 *     description: Returns the current status of the API server
 *     tags: [Health]
 *     responses:
 *       200:
 *         description: API is running successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/HealthResponse'
 */
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Alleviate Health API is running',
    timestamp: new Date().toISOString()
  });
});

/**
 * @swagger
 * /settings/phone:
 *   post:
 *     summary: Update phone number in website settings
 *     description: Updates the phone number in the Alleviate Health platform settings using Playwright automation
 *     tags: [Settings]
 *     security:
 *       - BasicAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/PhoneUpdateRequest'
 *           example:
 *             phoneNumber: "+1234567890"
 *     responses:
 *       200:
 *         description: Phone number updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/SuccessResponse'
 *       400:
 *         description: Bad request - missing required fields
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Unauthorized - Basic authentication required
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Basic Authentication required"
 *                 example:
 *                   type: string
 *                   example: "Authorization: Basic <base64-encoded-credentials>"
 *       500:
 *         description: Internal server error
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: string
 *                   example: "Failed to update phone number"
 *                 message:
 *                   type: string
 *                   example: "Error details"
 */
app.post('/settings/phone', async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    
    // Extract Basic Auth credentials from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Basic ')) {
      return res.status(401).json({ 
        error: 'Basic Authentication required',
        example: 'Authorization: Basic ' + Buffer.from('username:password').toString('base64')
      });
    }

    // Decode Basic Auth credentials
    const base64Credentials = authHeader.split(' ')[1];
    const credentials = Buffer.from(base64Credentials, 'base64').toString('ascii');
    const [username, password] = credentials.split(':');

    if (!username || !password) {
      return res.status(401).json({ 
        error: 'Invalid Basic Auth format',
        example: 'Authorization: Basic ' + Buffer.from('username:password').toString('base64')
      });
    }
    
    // Validate required fields
    if (!phoneNumber) {
      return res.status(400).json({ 
        error: 'Phone number is required',
        example: { phoneNumber: '+1234567890' }
      });
    }

    // Launch browser and create page
    const browser = await chromium.launch({ headless: true }); // Set to true for headless mode
    const page = await browser.newPage();

    await page.goto('https://platform.alleviatehealth.care/login');
    await page.getByRole('textbox', { name: 'Email address' }).click();
    await page.getByRole('textbox', { name: 'Email address' }).fill(username);
    await page.getByRole('textbox', { name: 'Password' }).fill(password);
    
    await Promise.all([
        page.waitForResponse(res =>
          res.url().includes("/login") && res.status() === 200
        ),
        await page.getByRole('button', { name: 'Login' }).click()
    ]);

    // Adding this because /login returns 200 even if login is failed
    await Promise.race([
        page.waitForURL("**/trials", { timeout: 5000 }), // waits for new URL
        page.waitForTimeout(2000) // just waits 2s
    ]);

    if (!page.url().includes("/trials")) {
        await browser.close();
        return res.json({
            success: false,
            message: 'Login failed',
        });
    }


    await page.getByRole('link', { name: 'Settings' }).click();
    await page.waitForURL("**/settings", { timeout: 5000 });

    await page.getByRole('row').filter({ hasText: /^$/ }).getByRole('cell').click();
    await page.getByRole('row').filter({ hasText: 'Select Site' }).getByRole('textbox').fill(phoneNumber);
    await page.getByRole('combobox').filter({ hasText: 'Select Site' }).click();
    await page.getByRole('option', { name: 'Default' }).click();

    const [response] = await Promise.all([
        page.waitForResponse(res =>
          res.url().includes("/settings") && res.status() === 200
        ),
        await page.getByRole('button', { name: 'Save changes' }).click()
    ]);

    await page.waitForTimeout(3000); // this is just to be safe, and will slow it down a bit. We can look to remove later.
    await browser.close();
    
    // Success response
    if (response.status() == 200) {
        res.json({
            success: true,
            message: 'Phone number updated successfully',
            data: {
                phoneNumber: phoneNumber,
                status: 'completed'
            },
            updatedAt: new Date().toISOString()
        });
    }
    else {
        res.json({
            success: false,
            message: 'Phone number update failed',
            data: {
                phoneNumber: phoneNumber,
                status: 'failed'
            },
        });
    }

    
  } catch (error) {
    console.error('Phone number update error:', error);
    
    if (typeof browser !== 'undefined') {
      await browser.close();
    }
    
    res.status(500).json({ 
      error: 'Failed to update phone number',
      message: error.message 
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    error: 'Something went wrong!',
    message: err.message 
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    availableEndpoints: [
      'GET /health',
      'POST /settings/phone'
    ]
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Alleviate Health API server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📚 API Documentation: http://localhost:${PORT}/api-docs`);
  console.log(`📱 Available endpoints:`);
  console.log(`   POST /settings/phone - Update phone number in website settings`);
});
