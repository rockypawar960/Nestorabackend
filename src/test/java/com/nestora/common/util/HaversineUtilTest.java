package com.nestora.common.util;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

class HaversineUtilTest {

    private static final double TOLERANCE_KM = 1.0;

    @Test
    void samePoint_returnsZero() {
        double distance = HaversineUtil.distanceKm(28.6139, 77.2090, 28.6139, 77.2090);
        assertThat(distance).isCloseTo(0.0, within(0.001));
    }

    @Test
    void delhiToAgra_returnsApproxCorrectDistance() {
        // Delhi: 28.6139, 77.2090 | Agra: 27.1767, 78.0081 (~179 - 206 km depending on points)
        double distance = HaversineUtil.distanceKm(28.6139, 77.2090, 27.1767, 78.0081);
        assertThat(distance).isGreaterThan(170.0).isLessThan(210.0);
    }

    @Test
    void mumbaiToPune_returnsApproxCorrectDistance() {
        // Mumbai: 19.0760, 72.8777 | Pune: 18.5204, 73.8567 (~120 - 150 km)
        double distance = HaversineUtil.distanceKm(19.0760, 72.8777, 18.5204, 73.8567);
        assertThat(distance).isGreaterThan(115.0).isLessThan(155.0);
    }

    @Test
    void distanceIsSymmetric() {
        double ab = HaversineUtil.distanceKm(12.9716, 77.5946, 13.0827, 80.2707);
        double ba = HaversineUtil.distanceKm(13.0827, 80.2707, 12.9716, 77.5946);
        assertThat(ab).isCloseTo(ba, within(0.001));
    }

    @Test
    void shortDistance_isReasonable() {
        double distance = HaversineUtil.distanceKm(23.2599, 77.4126, 23.2100, 77.4700);
        assertThat(distance).isGreaterThan(0.0).isLessThan(15.0);
    }
}
