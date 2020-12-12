import 'dart:io';

import 'package:Viiddo/utils/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_rsa/simple_rsa.dart';

import 'jsonable.dart';

enum RestCallType { get, post, formPost, put, delete }

class BaseClient {
  Dio _dio = Dio();

  Future<T> delete<T extends Jsonable>(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
  }) async {
    return _request(
      path,
      RestCallType.delete,
      queryParameters: queryParameters,
      headers: headers,
      type: type,
    );
  }

  Future<Response> deleteTypeless(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
  }) async {
    return _requestTypeless(
      path,
      RestCallType.delete,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> get<T extends Jsonable>(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
  }) async {
    return _request(
      path,
      RestCallType.get,
      queryParameters: queryParameters,
      headers: headers,
      type: type,
    );
  }

  Future<List<T>> getArray<T extends Jsonable>(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
  }) async {
    Response response = await _requestTypeless(
      path,
      RestCallType.get,
      queryParameters: queryParameters,
      headers: headers,
    );
    List<dynamic> list = response.data;
    List<Map> maps = list.cast<Map<dynamic, dynamic>>();
    List<T> models = maps.map((Map<dynamic, dynamic> map) {
      return type.fromJson(map) as T;
    }).toList();

    return models;
  }

  Future<Response> getTypeless(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
  }) async {
    return _requestTypeless(
      path,
      RestCallType.get,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<T> post<T extends Jsonable>(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
    Map<String, dynamic> body,
  }) async {
    return _request(
      path,
      RestCallType.post,
      queryParameters: queryParameters,
      headers: headers,
      type: type,
      data: body,
    );
  }

  Future<Response> postForm(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    FormData body,
  }) async {
    return _requestTypeless(
      path,
      RestCallType.formPost,
      queryParameters: queryParameters,
      headers: headers,
      data: body,
    );
  }

  Future<T> put<T extends Jsonable>(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
  }) async {
    return _request(
      path,
      RestCallType.put,
      queryParameters: queryParameters,
      headers: headers,
      type: type,
    );
  }

  Future<Response> putTypeless(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    dynamic body,
  }) async {
    return _requestTypeless(
      path,
      RestCallType.put,
      queryParameters: queryParameters,
      headers: headers,
      data: body,
    );
  }

  Future<Response> putJson(
    String path, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    Map<String, dynamic> body,
  }) async {
    return _requestTypeless(
      path,
      RestCallType.put,
      queryParameters: queryParameters,
      data: body,
      headers: headers,
    );
  }

  Future<T> _request<T extends Jsonable>(
    String path,
    RestCallType callType, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    T type,
    Map<String, dynamic> data,
  }) async {
    bool reAuthRequired = false;
    T model;
    do {
      if (headers == null) {
        headers = {};
      }
//      List<String> cookies = await CookieUtils.getCookies();
//      if (cookies != null) {
//        Map<String, List<String>> cookieHeaders = {'cookie': cookies};
//        headers.addAll(cookieHeaders);
//      }

      Response response;
      try {
        if (callType == RestCallType.get) {
          response = await _dio.get(
            path,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.post) {
          response = await _dio.post(
            path,
            data: data,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.put) {
          response = await _dio.put(
            path,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.delete) {
          response = await _dio.delete(
            path,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        }
      } on DioError catch (e) {
        debugPrint('Dio error: $e');
        if (e.response.statusCode == 401 || e.response.statusCode == 302) {
//          bool reAuthResult = await _authService.reAuth();
//          if (reAuthResult) {
//            reAuthRequired = true;
//            continue;
//          } else {
//            // TODO: throw error? (that app caches and sends you back to login?)
//            reAuthRequired = false;
//          }
        } else {
          // allow all non-auth errors to bubble up to callers
          rethrow;
        }
      }
      reAuthRequired = false;
      if (response.statusCode != 204 &&
          (response.data ?? '').toString().isNotEmpty) {
        model = type.fromJson(response.data);
      }
    } while (reAuthRequired);

    return model;
  }

  Future<Response> _requestTypeless(
    String path,
    RestCallType callType, {
    Map<String, dynamic> queryParameters,
    Map<String, dynamic> headers,
    dynamic data,
  }) async {
    bool reAuthRequired = false;
    Response response;

    do {
      if (headers == null) {
        headers = {};
      }
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      String token = sharedPreferences.getString(Constants.TOKEN);
      String endcryptString =
          await encryptString(Constants.netWorkTicket, Constants.rsaPublicKey);
//      headers['ticket'] = endcryptString;

      if (token != null && token.length > 0) {
        headers['token'] = token;
      }
//      List<String> cookies = await CookieUtils.getCookies();
//      if (cookies != null) {
//        Map<String, List<String>> cookieHeaders = {'cookie': cookies};
//        headers.addAll(cookieHeaders);
//      }

      try {
        if (callType == RestCallType.get) {
          response = await _dio.get(
            path,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.formPost) {
          response = await _dio.post(
            path,
            data: data,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              validateStatus: (int status) {
                return status == HttpStatus.found || status == HttpStatus.ok;
              },
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.post) {
          response = await _dio.post(
            path,
            data: data,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.put) {
          response = await _dio.put(
            path,
            data: data,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        } else if (callType == RestCallType.delete) {
          response = await _dio.delete(
            path,
            queryParameters: queryParameters,
            options: Options(
              headers: headers,
              followRedirects: false,
            ),
          );
        }
      } on DioError catch (e) {
        debugPrint('Dio error: $e');
        if (e.response.statusCode == 403) {
//          bool reAuthResult = await _authService.reAuth();
//          if (reAuthResult) {
//            reAuthRequired = true;
//            continue;
//          } else {
//            // TODO: throw error? (that app caches and sends you back to login?)
//            reAuthRequired = false;
//          }
        } else {
          // allow all non-auth errors to bubble up to callers
          rethrow;
        }
      }
      reAuthRequired = false;
    } while (reAuthRequired);
    return response;
  }
}
