#ifndef NUTRITION_CORE_H
#define NUTRITION_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    TD_MALE = 0,
    TD_FEMALE = 1
} TDGender;

typedef enum {
    TD_LOSE_WEIGHT = 0,
    TD_MAINTAIN = 1,
    TD_GAIN_WEIGHT = 2
} TDGoal;

typedef struct {
    int32_t gender;
    int32_t age;
    double height_cm;
    double weight_kg;
    double activity_factor;
    int32_t goal;
    int32_t family_members;
} TDNutritionInput;

typedef struct {
    double bmr_kcal;
    double tdee_kcal;
    double target_daily_kcal;
    double family_total_kcal;
    double serving_multiplier;
    double protein_g;
    double carbs_g;
    double fat_g;
} TDNutritionResult;

double td_calculate_bmr(int32_t gender, int32_t age, double height_cm, double weight_kg);
double td_calculate_tdee(double bmr, double activity_factor);
double td_calculate_target_calories(double tdee, int32_t goal);
double td_calculate_serving_multiplier(double base_day_kcal, double target_day_kcal);
double td_scale_amount(double base_amount, double multiplier, int32_t family_members);
TDNutritionResult td_evaluate_profile(TDNutritionInput input, double base_day_kcal);

#ifdef __cplusplus
}
#endif

#endif
