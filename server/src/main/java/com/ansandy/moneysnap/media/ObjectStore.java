package com.ansandy.moneysnap.media;

import java.util.concurrent.ConcurrentHashMap;

interface ObjectStore {

    void put(String key, byte[] bytes);

    byte[] get(String key, int maxBytes);

    void delete(String key);

    boolean exists(String key);
}

final class MemoryObjectStore implements ObjectStore {

    private final ConcurrentHashMap<String, byte[]> objects = new ConcurrentHashMap<>();
    private int remainingDeleteFailures;

    void failNextDeletes(int count) {
        remainingDeleteFailures = count;
    }

    @Override
    public void put(String key, byte[] bytes) {
        objects.put(key, bytes);
    }

    @Override
    public byte[] get(String key, int maxBytes) {
        byte[] stored = objects.get(key);
        if (stored == null) {
            return null;
        }
        if (stored.length > maxBytes) {
            throw new IllegalArgumentException("Object exceeds bounded read");
        }
        return stored;
    }

    @Override
    public void delete(String key) {
        if (remainingDeleteFailures > 0) {
            remainingDeleteFailures--;
            throw new IllegalStateException("transient object delete failure");
        }
        objects.remove(key);
    }

    @Override
    public boolean exists(String key) {
        return objects.containsKey(key);
    }
}
