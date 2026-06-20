"use client";

import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  ReactNode,
} from "react";

interface ReadStateContextType {
  isRead: (id: string) => boolean;
  markAsRead: (id: string) => void;
  markAllAsRead: (ids: string[]) => void;
  readCount: number;
}

const ReadStateContext = createContext<ReadStateContextType>({
  isRead: () => false,
  markAsRead: () => {},
  markAllAsRead: () => {},
  readCount: 0,
});

const STORAGE_KEY = "discover-dashboard-read";

export function ReadStateProvider({ children }: { children: ReactNode }) {
  const [readIds, setReadIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as string[];
        setReadIds(new Set(parsed));
      }
    } catch {
      // ignore
    }
  }, []);

  const persist = useCallback((ids: Set<string>) => {
    try {
      const arr = Array.from(ids);
      // Keep only last 2000 entries to prevent bloat
      const trimmed = arr.slice(-2000);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(trimmed));
    } catch {
      // ignore
    }
  }, []);

  const isRead = useCallback((id: string) => readIds.has(id), [readIds]);

  const markAsRead = useCallback(
    (id: string) => {
      setReadIds((prev) => {
        const next = new Set(prev);
        next.add(id);
        persist(next);
        return next;
      });
    },
    [persist]
  );

  const markAllAsRead = useCallback(
    (ids: string[]) => {
      setReadIds((prev) => {
        const next = new Set(prev);
        ids.forEach((id) => next.add(id));
        persist(next);
        return next;
      });
    },
    [persist]
  );

  return (
    <ReadStateContext.Provider
      value={{ isRead, markAsRead, markAllAsRead, readCount: readIds.size }}
    >
      {children}
    </ReadStateContext.Provider>
  );
}

export function useReadState() {
  return useContext(ReadStateContext);
}
