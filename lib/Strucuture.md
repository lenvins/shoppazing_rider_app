lib/
│
├── main.dart (refactored for Riverpod)
│
├── config/
│   ├── app_config.dart
│   ├── router.dart (go_router for navigation)
│   └── theme.dart
│
├── constants/
│   ├── app_constants.dart
│   ├── api_constants.dart
│   └── route_constants.dart
│
├── models/
│   ├── entities/
│   │   ├── order.dart
│   │   ├── chat_message.dart
│   │   ├── user.dart
│   │   ├── rider.dart
│   │   └── transaction.dart
│   ├── requests/
│   │   ├── otp_request.dart
│   │   ├── login_request.dart
│   │   └── order_request.dart
│   └── responses/
│       ├── api_response.dart
│       └── auth_response.dart
│
├── providers/
│   ├── _shared/
│   │   ├── api_provider.dart (HTTP client setup)
│   │   ├── database_provider.dart (SQLite)
│   │   └── firebase_provider.dart (Firebase setup)
│   │
│   ├── auth/
│   │   ├── auth_state_provider.dart
│   │   ├── user_session_provider.dart
│   │   └── auth_service_provider.dart
│   │
│   ├── orders/
│   │   ├── orders_state_provider.dart
│   │   ├── orders_notifier.dart
│   │   ├── order_details_provider.dart
│   │   └── orders_service_provider.dart
│   │
│   ├── chat/
│   │   ├── chat_messages_provider.dart
│   │   ├── chat_service_provider.dart
│   │   └── chat_notifier.dart
│   │
│   ├── dashboard/
│   │   ├── dashboard_state_provider.dart
│   │   ├── dashboard_notifier.dart
│   │   └── dashboard_service_provider.dart
│   │
│   ├── user/
│   │   ├── user_profile_provider.dart
│   │   ├── user_location_provider.dart
│   │   └── user_service_provider.dart
│   │
│   ├── network/
│   │   ├── connectivity_provider.dart
│   │   └── network_service_provider.dart
│   │
│   └── app/
│       ├── app_state_provider.dart
│       └── notifications_provider.dart
│
├── services/
│   ├── api/
│   │   ├── api_client.dart (refactored with Riverpod)
│   │   └── api_interceptors.dart
│   ├── database/
│   │   ├── user_session_db.dart
│   │   └── rider_orders_db.dart
│   ├── firebase/
│   │   ├── chat_service.dart
│   │   ├── firestore_service.dart
│   │   └── fcm_service.dart
│   ├── device/
│   │   ├── device_service.dart
│   │   └── location_service.dart
│   ├── validation/
│   │   └── validation_service.dart
│   └── utils/
│       ├── network_service.dart
│       ├── navigation_service.dart
│       └── logger.dart
│
├── screens/
│   ├── auth/
│   │   ├── phone_number_screen.dart
│   │   ├── otp_screen.dart
│   │   ├── registration_screen.dart
│   │   └── email_login_screen.dart
│   │
│   ├── main_flow/
│   │   ├── home_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── account_screen.dart
│   │   └── root_navigator.dart (BottomNavBar container)
│   │
│   ├── order_management/
│   │   ├── orders_list_screen.dart
│   │   └── order_details_screen.dart
│   │
│   ├── chat/
│   │   └── chat_screen.dart
│   │
│   ├── payment/
│   │   └── payment_webview_screen.dart
│   │
│   ├── location/
│   │   └── map_screen.dart
│   │
│   └── common/
│       ├── loading_screen.dart
│       └── error_screen.dart
│
├── widgets/
│   ├── buttons/
│   │   ├── address_button.dart
│   │   └── mobile_phone_button.dart
│   │
│   ├── cards/
│   │   ├── order_card.dart
│   │   └── dashboard_card.dart
│   │
│   ├── dialogs/
│   │   ├── confirm_dialog.dart
│   │   └── error_dialog.dart
│   │
│   ├── loaders/
│   │   └── loading_widget.dart
│   │
│   ├── inputs/
│   │   ├── text_input_field.dart
│   │   └── pin_input_field.dart
│   │
│   └── common/
│       ├── network_error_banner.dart
│       └── custom_app_bar.dart
│
├── extensions/
│   ├── build_context_ext.dart
│   ├── string_ext.dart
│   ├── date_time_ext.dart
│   └── list_ext.dart
│
└── utils/
    ├── logger.dart
    ├── constants.dart
    └── extensions.dart