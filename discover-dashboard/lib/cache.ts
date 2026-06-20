import fs from "fs/promises";
import path from "path";
import os from "os";
import { Article } from "./types";

const CACHE_DIR = path.join(os.homedir(), ".config", "discover");
const CACHE_FILE = path.join(CACHE_DIR, "cache.json");

export interface CacheData {
    lastUpdated: number;
    articles: Article[];
}

export async function readCache(): Promise<CacheData | null> {
    try {
        const data = await fs.readFile(CACHE_FILE, "utf-8");
        return JSON.parse(data) as CacheData;
    } catch (error) {
        return null;
    }
}

export async function writeCache(articles: Article[]): Promise<void> {
    try {
        await fs.mkdir(CACHE_DIR, { recursive: true });
        const data: CacheData = {
            lastUpdated: Date.now(),
            articles,
        };
        await fs.writeFile(CACHE_FILE, JSON.stringify(data), "utf-8");
    } catch (error) {
        console.error("Failed to write to cache:", error);
    }
}
