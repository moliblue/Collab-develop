abstract final class PlannerMessages {
  static const noPlans =
      "You don't have any saved travel plans yet. Create your first plan to start arranging itinerary cards.";
  static String tabsCreated(int days) =>
      '$days days – $days Day tabs will be created';
  static const planCreated = 'New travel plan created successfully!';
  static String deletePlan(String title) =>
      'Are you sure you want to delete "$title"? All associated itinerary cards, date tabs, and group data will be permanently removed.';
  static const planDeleted = 'Travel plan and associated data deleted';
  static const exitGroupBeforeDelete =
      'You are still a member of this travel plan. Please exit the group first before deleting the plan.';
  static const planJoined = 'New plan added to your list';
  static const invalidCode = 'Invalid code, please try again';
  static const dateAdded = 'New date tab added chronologically!';
  static const dateUpdated = 'Date tab updated.';
  static String deleteDay(int day) =>
      'Delete Day $day? Associated itinerary cards will be removed.';
  static const dateRemoved = 'Date tab removed.';
  static const cardAdded = 'Trip card added successfully';
  static const requiredField = 'Please fill out this field.';
  static const noMatch = 'No matc found. Please enter again.';
  static String conflict(int count) => '$count Time Conflict Detected';
  static const conflictPrompt = 'click to resolve schedule overlap';
  static const recalculated =
      'Schedule time automatically recalculated and adjusted';
  static const routeUnavailable = 'Route data unavailable.';
  static String locationAdded(String name) => 'Added "$name';
  static const exportConfirm =
      'Are you sure you want to export this trip plan into PDF?';
  static const generatingPdf = 'Generating PDF';
  static const exportSuccess =
      'Trip plan exported successfully into PDF and downloaded!';
  static const noCards = 'Error: Need at least 1 card to export trip plan.';
  static const exportError = 'Exportation error: Please try again';
  static String deleteCard(String title) =>
      'Are you sure to  delete card $title?';
  static const cardRemoved = 'Itinerary card  removed.';
  static String redirectRoute(int day) =>
      'Reedirecting to map to show Day $day route in time order.';
  static const invitationShared = 'Trip invitation shared!';
  static const leaveConfirm = 'Are your sure you would like to leave?';
  static const adminTransferWarning =
      'Warning: You must transfer admin rights before leaving the group. Are you sure, you would like to proceed?';
  static const memberUpdated = 'Member list updated successfully.';
  static const removeMemberConfirm =
      'Are your sure you want to remove member selected?';
}
