package com.ansandy.moneysnap.group;

import java.text.BreakIterator;
import java.util.Locale;

record GroupName(String value) {

    GroupName {
        if (value == null) {
            throw new IllegalArgumentException("Group name is required");
        }
        String trimmed = value.strip();
        int graphemes = graphemeCount(trimmed);
        if (graphemes < 1 || graphemes > 30) {
            throw new IllegalArgumentException("Group name must be 1 to 30 grapheme clusters");
        }
        value = trimmed;
    }

    static int graphemeCount(String value) {
        BreakIterator iterator = BreakIterator.getCharacterInstance(Locale.ROOT);
        iterator.setText(value);
        int count = 0;
        while (iterator.next() != BreakIterator.DONE) {
            count++;
        }
        return count;
    }
}
