/*
 * This source file was generated by the Gradle 'init' task
 */
package org.example;

import org.example.App.StringMatcher;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.stream.Stream;

class AppTest {
    @Test
    void appHasAGreeting() {
        Assertions.assertEquals(
                Stream.of("use", "audio", "anyString").map(StringMatcher::exact).toList(),
                Stream.of("use", "audio", "*").map(StringMatcher::exact).toList()
        );

        Assertions.assertEquals(
                Stream.of("use", "audio", "*").map(StringMatcher::exact).toList(),
                Stream.of("use", "audio", "anyString").map(StringMatcher::exact).toList()
        );

        Assertions.assertNotEquals(
                Stream.of("use", "audio", "anyString").map(StringMatcher::exact).toList(),
                Stream.of("use", "audio", "123").map(StringMatcher::exact).toList()
        );

        Assertions.assertNotEquals(
                Stream.of("use", "audio", "*").map(StringMatcher::escape).toList(),
                Stream.of("use", "audio", "123").map(StringMatcher::exact).toList()
        );

        Assertions.assertEquals(
                Stream.of("use", "audio", "*").map(StringMatcher::escape).toList(),
                Stream.of("use", "audio", "*").map(StringMatcher::exact).toList()
        );

    }


}
