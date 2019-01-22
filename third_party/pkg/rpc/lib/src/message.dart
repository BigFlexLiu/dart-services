// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.messages;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'utils.dart';
import 'errors.dart';

/// Class used when invoking Http API requests.
///
/// It holds the information necessary to route the request and all
/// the parameters needed to invoke the method.
class HttpApiRequest {
  /// HTTP method for this request (e.g. GET, POST,...).
  final String httpMethod;

  /// Requested uri.
  /// This is the uri as generated by dart:io, see
  /// [here](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart:io.HttpRequest#id_requestedUri)
  /// for more details.
  final Uri uri;

  /// HTTP request headers.
  /// The headers values must be either String for single value headers
  /// or List<String> for multi value headers.
  final Map<String, dynamic> headers;

  /// Request body containing parameters for a POST request.
  final Stream<List<int>> body;

  // Request cookies (optional). Not supported with shelf_rpc.
  final List<Cookie> cookies;

  factory HttpApiRequest(String httpMethod, Uri uri,
      Map<String, dynamic> headers, Stream<List<int>> body,
      {List<Cookie> cookies}) {
    var headersLowerCase = new Map<String, dynamic>();
    headers.forEach((String key, dynamic value) =>
        headersLowerCase[key.toLowerCase()] = value);
    return new HttpApiRequest._(
        httpMethod, uri, headersLowerCase, cookies, body);
  }

  factory HttpApiRequest.fromHttpRequest(HttpRequest request) {
    // Convert HttpHeaders to a Map<String, dynamic>. We don't need to
    // lowercase the keys as they are already lowercased in the HttpRequest.
    var headers = new Map<String, dynamic>();
    request.headers
        .forEach((String key, dynamic value) => headers[key] = value);

    return new HttpApiRequest._(request.method, request.requestedUri, headers,
        request.cookies, request);
  }

  HttpApiRequest._(
      this.httpMethod, this.uri, this.headers, this.cookies, this.body);

  Map<String, dynamic> get queryParameters => uri.queryParameters;
}

/// Class for holding an HTTP API response.
///
/// This is the result of calling the API server's handleHttpRequest method.
class HttpApiResponse {
  // We have an encoder for all the supported encodings.
  // Currently only json is supported.
  static final _jsonToBytes = json.encoder.fuse(utf8.encoder);

  /// Status of the response, e.g. 200 if success, 400 if bad request, etc.
  final int status;

  /// HTTP response headers
  final Map<String, dynamic> headers;

  /// Response body containing the result of a request.
  final Stream<List<int>> body;

  /// Holds any exception resulting from a failed request.
  /// The exception is stored to allow the application server to log the error
  /// and/or return back more information about the failure to the client.
  final Exception exception;

  /// Holds a stacktrace if passed via constructor.
  final StackTrace stack;

  HttpApiResponse(this.status, this.body, this.headers,
      {this.exception, this.stack}) {
    assert(headers != null);
  }

  factory HttpApiResponse.error(
      int status, String message, Exception exception, StackTrace stack,
      {List<RpcErrorDetail> errors}) {
    Map json = {
      'error': {'code': status, 'message': message}
    };
    if (errors != null && errors.length > 0) {
      json['error']['errors'] = errors.map((error) => error.toJson()).toList();
    }
    Stream<List<int>> s = new Stream.fromIterable([_jsonToBytes.convert(json)]);
    return new HttpApiResponse(status, s, defaultResponseHeaders,
        exception: exception, stack: stack);
  }
}