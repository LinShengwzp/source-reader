enum SourceTestFailureReason {
  sourceNotFound,
  unsupportedPlatform,
  searchBookMissing,
  requestInfoMissing,
  unsupportedScriptRequest,
  unknownPlaceholder,
  invalidBaseUrl,
  invalidHeaders,
  unsupportedRequestEncoding,
  transportFailure,
  timeout,
  responseTooLarge,
  unsupportedResponseEncoding,
  unsupportedResponseFormat,
  responseParseFailure,
  listRuleFailure,
}

final class SourceTestException implements Exception {
  const SourceTestException(this.reason, {this.message, this.cause});
  final SourceTestFailureReason reason;
  final String? message;
  final Object? cause;
}
