import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import admin from "firebase-admin";
import { readFileSync } from "fs";
import { resolve } from "path";

// Path to the Firebase Admin service account key
// Provide this as a command-line argument or environment variable
const serviceAccountPath = process.argv[2] ?? process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!serviceAccountPath) {
    console.error("Usage: node index.js <path-to-service-account.json>");
    process.exit(1);
}

// Initialize Firebase
const serviceAccount = JSON.parse(readFileSync(resolve(serviceAccountPath), "utf8"));
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Create the MCP server
const server = new Server(
    { name: "firebase-mcp-server", version: "1.0.0" },
    { capabilities: { tools: {} } }
);

// Define tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            {
                name: "list_collections",
                description: "List all top-level collections in Firestore.",
                inputSchema: { type: "object", properties: {}, required: [] },
            },
            {
                name: "get_users",
                description: "Get all user documents from the 'users' collection.",
                inputSchema: { type: "object", properties: {}, required: [] },
            },
            {
                name: "get_user_todos",
                description: "Get 'todos' collection associated with a given userId.",
                inputSchema: {
                    type: "object",
                    properties: {
                        userId: { type: "string" },
                    },
                    required: ["userId"],
                },
            },
            {
                name: "get_document",
                description: "Get a specific document by its path (e.g., 'users/123/todos/abc').",
                inputSchema: {
                    type: "object",
                    properties: {
                        path: { type: "string" },
                    },
                    required: ["path"],
                },
            }
        ],
    };
});

// Handle tools
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    try {
        if (request.params.name === "list_collections") {
            const collections = await db.listCollections();
            return {
                content: [{ type: "text", text: JSON.stringify(collections.map(c => c.id)) }],
                isError: false,
            };
        }

        if (request.params.name === "get_users") {
            try {
                // MENGAMBIL DARI FIREBASE AUTHENTICATION (Bukan hanya dokumen database)
                // Ini memastikan semua user yang pernah register akan terbaca
                const authUsers = await admin.auth().listUsers(100);
                const data = authUsers.users.map(u => ({
                    id: u.uid,
                    email: u.email,
                    creationTime: u.metadata.creationTime
                }));
                return {
                    content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
                    isError: false,
                };
            } catch (err) {
                return {
                    content: [{ type: "text", text: `Auth Error: ${err.message}` }],
                    isError: true,
                };
            }
        }

        if (request.params.name === "get_user_todos") {
            const { userId } = request.params.arguments;
            const snapshot = await db.collection("users").doc(userId).collection("todos").get();
            const data = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            return {
                content: [{ type: "text", text: JSON.stringify(data, null, 2) }],
                isError: false,
            };
        }

        if (request.params.name === "get_document") {
            const { path } = request.params.arguments;
            const doc = await db.doc(path).get();
            if (!doc.exists) {
                return {
                    content: [{ type: "text", text: "Document not found" }],
                    isError: true,
                };
            }
            return {
                content: [{ type: "text", text: JSON.stringify({ id: doc.id, ...doc.data() }, null, 2) }],
                isError: false,
            };
        }

        return {
            content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }],
            isError: true,
        };
    } catch (error) {
        return {
            content: [{ type: "text", text: `Error: ${(error).message}` }],
            isError: true,
        };
    }
});

// Start the server
async function startServer() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("Firebase MCP server started.");
}
startServer();