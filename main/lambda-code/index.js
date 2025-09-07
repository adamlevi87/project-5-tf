// lambda-code/index.js
import { S3Client, PutObjectCommand, ListObjectsV2Command } from '@aws-sdk/client-s3';
import { randomUUID } from 'crypto';

// Initialize AWS S3 client
const s3Client = new S3Client({
    region: process.env.AWS_REGION || 'us-east-1'
});

async function updateIndexFile(s3Client, bucketName, fileName) {
    try {
        // Get list of all objects in messages/ folder
        const listParams = {
            Bucket: bucketName,
            Prefix: 'messages/'
        };
        
        const objects = await s3Client.listObjectsV2(listParams);
        
        // Create HTML content
        let html = `
<!DOCTYPE html>
<html>
<head>
    <title>Message Files</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        ul { list-style-type: none; }
        li { margin: 10px 0; }
        a { text-decoration: none; color: #0066cc; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>Message Files</h1>
    <ul>
`;

        // Add each file as a link
        objects.Contents?.forEach(obj => {
            if (obj.Key !== 'messages/' && obj.Key.endsWith('.json')) {
                const fileName = obj.Key.split('/').pop();
                html += `        <li><a href="${obj.Key}">${fileName}</a> (${obj.LastModified})</li>\n`;
            }
        });

        html += `    </ul>
</body>
</html>`;

        // Upload index.html to S3
        const indexParams = {
            Bucket: bucketName,
            Key: 'index.html',
            Body: html,
            ContentType: 'text/html'
        };
        
        await s3Client.send(new PutObjectCommand(indexParams));
        console.log('Index file updated');
        
    } catch (error) {
        console.error('Error updating index file:', error);
    }
}

export const handler = async (event) => {
    console.log('Lambda triggered with event:', JSON.stringify(event, null, 2));
    
    try {
        // Process each SQS message in the batch
        const results = await Promise.allSettled(
            event.Records.map(record => processMessage(record))
        );
        
        // Log any failures
        const failures = results.filter(result => result.status === 'rejected');
        if (failures.length > 0) {
            console.error(`Failed to process ${failures.length} messages:`, 
                failures.map(f => f.reason));
        }
        
        const successCount = results.filter(result => result.status === 'fulfilled').length;
        console.log(`Successfully processed ${successCount} out of ${event.Records.length} messages`);
        
        // If any message failed, throw error to trigger retry/DLQ behavior
        if (failures.length > 0) {
            throw new Error(`Failed to process ${failures.length} messages`);
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: `Processed ${successCount} messages successfully`
            })
        };
        
    } catch (error) {
        console.error('Error processing messages:', error);
        throw error; // Re-throw to trigger retry/DLQ behavior
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
        const key = `messages/${timestamp}-${randomUUID()}.json`;
        
        // Prepare S3 object data
        const objectData = {
            messageId: record.messageId,
            timestamp: new Date().toISOString(),
            originalMessage: messageBody,
            processedBy: 'lambda-message-processor',
            runtime: 'nodejs22.x'
        };
        
        // Create PutObject command
        const putCommand = new PutObjectCommand({
            Bucket: process.env.S3_BUCKET,
            Key: key,
            Body: JSON.stringify(objectData, null, 2),
            ContentType: 'application/json',
            Metadata: {
                'message-id': record.messageId,
                'processed-at': new Date().toISOString()
            }
        });
        
        // Save to S3
        console.log(`Saving to S3: ${process.env.S3_BUCKET}/${key}`);
        await s3Client.send(putCommand);
        
        // Update index.html file
        await updateIndexFile(s3Client, process.env.S3_BUCKET);
        
        console.log(`Successfully saved message ${record.messageId} to S3`);
        return { messageId: record.messageId, status: 'success', s3Key: key };
        
    } catch (error) {
        console.error(`Error processing message ${record.messageId}:`, error);
        throw error; // Re-throw to trigger retry
    }
}