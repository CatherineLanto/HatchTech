# Batch System Enhancement Suggestions

## Current Editable Fields
- ✅ Batch Name (text)
- ✅ Incubation Days (number)

## Suggested Additional User Input Fields

### Basic Batch Information
- **Egg Breed/Type**: Dropdown (Chicken, Duck, Goose, Turkey, etc.)
- **Number of Eggs**: Input field for initial egg count
- **Expected Hatch Date**: Auto-calculated from start date + incubation days
- **Batch Notes**: Text area for user notes

### Advanced Tracking
- **Candling Dates**: Mark when candling was performed (days 7, 14, 18)
- **Fertility Rate**: Percentage after first candling
- **Development Progress**: Track viable eggs at each candling
- **Hatch Success**: Final count of successfully hatched eggs

### Environmental Preferences
- **Target Temperature**: Custom temp for this batch type
- **Target Humidity**: Custom humidity for this batch type
- **Turning Frequency**: How often eggs should be turned

### Implementation Priority
1. **High Priority**: Egg count, breed type, batch notes
2. **Medium Priority**: Candling tracking, fertility rates
3. **Low Priority**: Custom environmental settings per batch

## Current User Workflow
1. User taps batch card → sees details
2. User taps "Edit" → can modify name and incubation days
3. Changes are saved to local data structure
4. Progress automatically calculated from start date

## Suggested Enhanced Workflow
1. **New Batch Creation**: Dedicated "Start New Batch" button
2. **Batch Setup Wizard**: Step-by-step setup with all fields
3. **Candling Reminders**: Notifications when candling is due
4. **Progress Tracking**: Visual timeline with milestones
5. **Hatch Recording**: Final results input when batch completes
