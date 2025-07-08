// lambda-code/index.js
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS services
const s3 = new AWS.S3();

exports.handler = async (event) => {
    console.log('Lambda triggered with event:', JSON.stringify(event, null, 2));
    
    try {
        // Process each SQS message in the batch
        for (const record of event.Records) {
            await processMessage(record);
        }
        
        console.log(`Successfully processed ${event.Records.length} messages`);
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: `Processed ${event.Records.length} messages successfully`
            })
        };
        
    } catch (error) {
        console.error('Error processing messages:', error);
        
        // Re-throw error to trigger retry/DLQ behavior
        throw error;
    }
};

async function processMessage(record) {
    console.log('Processing message:', record.messageId);
    
    try {
        // Parse the message body (your backend sends JSON)
        const messageBody = JSON.parse(record.body);
        console.log('Message content:', messageBody);
        
        // Create S3 object key with timestamp and unique ID
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const key = `messages/${timestamp}-${uuidv4()}.json`;
        
        // Prepare S3 object
        const s3Params = {
            Bucket: process.env.S3_BUCKET,
            Key: key,
            Body: JSON.stringify({
                messageId: record.messageId,
                timestamp: new Date().toISOString(),
                originalMessage: messageBody,
                processedBy: 'lambda-message-processor'
            }, null, 2),
            ContentType: 'application/json'
        };
        
        // Save to S3
        console.log(`Saving to S3: ${s3Params.Bucket}/${key}`);
        await s3.putObject(s3Params).promise();
        
        console.log(`Successfully saved message ${record.messageId} to S3`);
        
    } catch (error) {
        console.error(`Error processing message ${record.messageId}:`, error);
        throw error; // Re-throw to trigger retry
    }
}