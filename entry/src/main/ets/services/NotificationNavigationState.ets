export class NotificationNavigationState {
  private static pendingEventId?: number

  static setPendingEventId(eventId?: number): void {
    NotificationNavigationState.pendingEventId = eventId
  }

  static consumePendingEventId(): number | undefined {
    const eventId = NotificationNavigationState.pendingEventId
    NotificationNavigationState.pendingEventId = undefined
    return eventId
  }
}
