# Experimental Sing-to-Dismiss Alarm

## Goal
Create a motivational alarm challenge where Shenghai asks the user to sing a whole song before the app marks the alarm as resolved.

This belongs in `Experimental` because it mixes habit design, sleep/wake behavior, microphone input, accessibility, and Apple platform limits.

## Current feasible version
- Shenghai schedules a system alert or notification for the wake time.
- The alert guides the user to open Shenghai.
- Shenghai starts a full-song singing challenge, currently using `Happy Birthday` as the first demo template.
- The app tracks:
  - target note coverage
  - in-tune ratio
  - attempt count
  - challenge completion
  - emergency bypass usage
- The app-level alarm state is marked resolved only when coverage and pitch thresholds are met.

## Platform boundary
On the current package targets, iOS 17 and macOS 14, Shenghai should not promise that it can force an alarm to keep ringing, record the microphone, or prevent dismissal while the app is closed, the screen is off, the device is muted, Focus is active, the device is powered off, or notifications are disabled.

Apple's user notification system can deliver alerts when the app is inactive, and newer AlarmKit APIs can create more prominent alarm presentations on newer iOS versions. The actual singing challenge still needs the app to open and use microphone permission.

## Safety and accessibility
This must never be used for life-critical alarms, medication reminders, safety reminders, or emergency wake-up needs.

Keep an emergency bypass because users may be sick, hoarse, in a shared room, unable to sing, using a device with broken microphone input, or in a situation where continuing the challenge is unsafe.

## App implementation
- Core model: `SingToDismissAlarmPlan`
- Evaluation: `SingToDismissAlarmEvaluator`
- Experimental catalog entry: `ExperimentalFeatureCatalog.singToDismissAlarm`
- First song template: `Happy Birthday`
- UI surface: `ExperimentalFeaturesView`

## Future implementation path
1. Add local notification scheduling and permission request UI.
2. Add a saved alarm list with enabled/disabled state.
3. Add a challenge screen that reuses live microphone pitch tracking.
4. Add configurable songs from MusicXML target timelines.
5. Investigate AlarmKit for iOS versions that support it.
6. Add accessibility alternatives such as humming, solfege, tapping rhythm, or emergency bypass.

