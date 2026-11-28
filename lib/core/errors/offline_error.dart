import 'api_exception.dart';

/// True when [error] means "no network or no server": nothing was sent.
///
/// The app reads offline but never writes offline (MVP): nothing is kept on
/// the device to send later. The person tries again once connected.
bool isOfflineError(Object error) =>
    error is ApiException &&
    (error.kind == ApiErrorKind.offline ||
        error.kind == ApiErrorKind.network ||
        error.kind == ApiErrorKind.timeout ||
        (error.statusCode ?? 0) >= 500);
