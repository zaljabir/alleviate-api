// Simple test script to demonstrate API usage
const fetch = require('node-fetch');

const API_BASE = 'http://localhost:3000';

async function testAPI() {
  console.log('🧪 Testing Alleviate Health API...\n');

  try {
    // Test health endpoint
    console.log('1. Testing health endpoint...');
    const healthResponse = await fetch(`${API_BASE}/health`);
    const healthData = await healthResponse.json();
    console.log('✅ Health check:', healthData);
    console.log('');

    // Test phone number update endpoint
    console.log('2. Testing phone number update endpoint...');
    const phoneResponse = await fetch(`${API_BASE}/settings/phone`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + Buffer.from('zain@alleviatehealth.care:testalleviate123').toString('base64')
      },
      body: JSON.stringify({ 
        phoneNumber: '+1234567890'
      })
    });
    const phoneData = await phoneResponse.json();
    console.log('✅ Phone update result:', {
      success: phoneData.success,
      message: phoneData.message,
      phoneNumber: phoneData.data?.phoneNumber,
      websiteUrl: phoneData.data?.websiteUrl,
      status: phoneData.data?.status
    });
    console.log('');

    // Test validation (missing phone number)
    console.log('3. Testing validation (missing phone number)...');
    const validationResponse = await fetch(`${API_BASE}/settings/phone`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Authorization': 'Basic ' + Buffer.from('zain@alleviatehealth.care:testalleviate123').toString('base64')
      },
      body: JSON.stringify({})
    });
    const validationData = await validationResponse.json();
    console.log('✅ Validation test:', {
      status: validationResponse.status,
      error: validationData.error
    });
    console.log('');

    console.log('🎉 All tests completed successfully!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    console.log('\n💡 Make sure the server is running: npm start');
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  testAPI();
}

module.exports = { testAPI };
