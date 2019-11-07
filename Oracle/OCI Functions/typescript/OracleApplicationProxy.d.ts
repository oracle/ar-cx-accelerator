export as namespace OracleApplicationProxy;

export interface RequestInput {
    hostname: string;
    method: string;
    path: string;
    headers?: any;
    payload?: String;
}