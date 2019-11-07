export as namespace KnowledgeAdvanced;

export interface AuthRequest {
    siteName: string;
    login: string;
    password: string;
}

export interface AuthResponse {
    authenticationToken: string;
}