abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String displayName;
  ProfileLoaded(this.displayName);
}

class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}
