#include "nutrition_core.h"
#include <math.h>

static double td_clamp_double(double value, double min_val, double max_val, double fallback) {
    if (isnan(value)) {
        return fallback;
    }
    if (value < min_val) {
        return min_val;
    }
    if (value > max_val) {
        return max_val;
    }
    return value;
}

static int32_t td_clamp_int32(int32_t value, int32_t min_val, int32_t max_val) {
    if (value < min_val) {
        return min_val;
    }
    if (value > max_val) {
        return max_val;
    }
    return value;
}

double td_calculate_bmr(int32_t gender, int32_t age, double height_cm, double weight_kg) {
    int32_t clamped_age = td_clamp_int32(age, 10, 120);
    double clamped_height = td_clamp_double(height_cm, 100.0, 250.0, 165.0);
    double clamped_weight = td_clamp_double(weight_kg, 25.0, 300.0, 60.0);

    double base = (10.0 * clamped_weight) + (6.25 * clamped_height) - (5.0 * (double)clamped_age);
    if (gender == TD_FEMALE) {
        return base - 161.0;
    }
    return base + 5.0;
}

double td_calculate_tdee(double bmr, double activity_factor) {
    double safe_bmr = (isnan(bmr) || isinf(bmr) || bmr < 0.0) ? 0.0 : bmr;
    double clamped_activity = td_clamp_double(activity_factor, 1.1, 2.2, 1.2);
    return safe_bmr * clamped_activity;
}

double td_calculate_target_calories(double tdee, int32_t goal) {
    double safe_tdee = (isnan(tdee) || isinf(tdee) || tdee < 0.0) ? 0.0 : tdee;

    switch (goal) {
        case TD_LOSE_WEIGHT:
            return fmax(1200.0, safe_tdee - 400.0);
        case TD_GAIN_WEIGHT:
            return safe_tdee + 350.0;
        case TD_MAINTAIN:
        default:
            return safe_tdee;
    }
}

double td_calculate_serving_multiplier(double base_day_kcal, double target_day_kcal) {
    if (isnan(base_day_kcal) || isinf(base_day_kcal) || base_day_kcal <= 0.0) {
        return 1.0;
    }
    if (isnan(target_day_kcal) || isinf(target_day_kcal) || target_day_kcal <= 0.0) {
        return 1.0;
    }

    double raw = target_day_kcal / base_day_kcal;
    double clamped = td_clamp_double(raw, 0.60, 1.80, 1.0);
    return round(clamped * 20.0) / 20.0;
}

double td_scale_amount(double base_amount, double multiplier, int32_t family_members) {
    if (isnan(base_amount) || isinf(base_amount) || base_amount <= 0.0) {
        return 0.0;
    }

    double clamped_multiplier = td_clamp_double(multiplier, 0.60, 1.80, 1.0);
    int32_t clamped_family = td_clamp_int32(family_members, 1, 12);
    return base_amount * clamped_multiplier * (double)clamped_family;
}

TDNutritionResult td_evaluate_profile(TDNutritionInput input, double base_day_kcal) {
    int32_t clamped_family = td_clamp_int32(input.family_members, 1, 12);
    double bmr = td_calculate_bmr(input.gender, input.age, input.height_cm, input.weight_kg);
    double tdee = td_calculate_tdee(bmr, input.activity_factor);
    double target = td_calculate_target_calories(tdee, input.goal);
    double multiplier = td_calculate_serving_multiplier(base_day_kcal, target);

    double protein_ratio = 0.25;
    double carbs_ratio = 0.50;
    double fat_ratio = 0.25;

    if (input.goal == TD_LOSE_WEIGHT) {
        protein_ratio = 0.30;
        carbs_ratio = 0.40;
        fat_ratio = 0.30;
    } else if (input.goal == TD_GAIN_WEIGHT) {
        protein_ratio = 0.25;
        carbs_ratio = 0.55;
        fat_ratio = 0.20;
    }

    TDNutritionResult result;
    result.bmr_kcal = bmr;
    result.tdee_kcal = tdee;
    result.target_daily_kcal = target;
    result.family_total_kcal = target * (double)clamped_family;
    result.serving_multiplier = multiplier;
    result.protein_g = (target * protein_ratio) / 4.0;
    result.carbs_g = (target * carbs_ratio) / 4.0;
    result.fat_g = (target * fat_ratio) / 9.0;
    return result;
}
