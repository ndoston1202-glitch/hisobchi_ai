import 'package:flutter/material.dart';

/// Bazada ikonka kalit so'z sifatida saqlanadi; bu yerda Material ikonkaga aylanadi.
const appIcons = <String, IconData>{
  'cash': Icons.payments_rounded,
  'card': Icons.credit_card_rounded,
  'phone': Icons.phone_android_rounded,
  'bank': Icons.account_balance_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'piggy': Icons.savings_rounded,
  'salary': Icons.work_rounded,
  'plus': Icons.add_circle_rounded,
  'debt_in': Icons.south_west_rounded,
  'debt_out': Icons.north_east_rounded,
  'handshake': Icons.handshake_rounded,
  'taxi': Icons.local_taxi_rounded,
  'lunch': Icons.lunch_dining_rounded,
  'basket': Icons.shopping_basket_rounded,
  'bolt': Icons.bolt_rounded,
  'more': Icons.more_horiz_rounded,
  'home': Icons.home_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'bus': Icons.directions_bus_rounded,
  'coffee': Icons.local_cafe_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'clothes': Icons.checkroom_rounded,
  'health': Icons.medical_services_rounded,
  'pharmacy': Icons.local_pharmacy_rounded,
  'education': Icons.school_rounded,
  'book': Icons.menu_book_rounded,
  'sport': Icons.fitness_center_rounded,
  'game': Icons.sports_esports_rounded,
  'movie': Icons.movie_rounded,
  'travel': Icons.flight_rounded,
  'gift': Icons.card_giftcard_rounded,
  'kids': Icons.child_care_rounded,
  'pet': Icons.pets_rounded,
  'internet': Icons.wifi_rounded,
  'mobile': Icons.smartphone_rounded,
  'water': Icons.water_drop_rounded,
  'repair': Icons.build_rounded,
  'beauty': Icons.content_cut_rounded,
  'business': Icons.storefront_rounded,
  'trend': Icons.trending_up_rounded,
  'bonus': Icons.stars_rounded,
  'charity': Icons.volunteer_activism_rounded,
  'tax': Icons.receipt_long_rounded,
};

const walletIconKeys = ['cash', 'card', 'phone', 'bank', 'wallet', 'piggy'];

IconData iconFor(String key) => appIcons[key] ?? Icons.circle_outlined;

/// Tur rangi tanlash palitrasi.
const typeColors = <int>[
  0xFF10B981, 0xFF14B8A6, 0xFF0EA5E9, 0xFF3B82F6, 0xFF6366F1, 0xFF8B5CF6,
  0xFFEC4899, 0xFFF43F5E, 0xFFF97316, 0xFFF59E0B, 0xFFEAB308, 0xFF84CC16,
  0xFF64748B, 0xFF94A3B8,
];
