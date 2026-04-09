// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'courses_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$courseRepositoryHash() => r'56466c4a4ee44fc5ffbe4881b1d461c5588979be';

/// See also [courseRepository].
@ProviderFor(courseRepository)
final courseRepositoryProvider = Provider<CourseRepository>.internal(
  courseRepository,
  name: r'courseRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$courseRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CourseRepositoryRef = ProviderRef<CourseRepository>;
String _$coursesHash() => r'8c22b9374b9ea3677e3904d8ff1afbc5852731d1';

/// Loads courses with enrollment counts; [CourseListFilter] via [setFilter].
///
/// Copied from [Courses].
@ProviderFor(Courses)
final coursesProvider =
    AsyncNotifierProvider<Courses, List<CourseListItem>>.internal(
      Courses.new,
      name: r'coursesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$coursesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Courses = AsyncNotifier<List<CourseListItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
