import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NeedLoginException extends ApiException {
  const NeedLoginException() : super('NEED_LOGIN', statusCode: 20010);
}

class NoCopyrightException extends ApiException {
  const NoCopyrightException([String? songName])
      : super(
          songName != null ? '无法播放：$songName 暂无版权' : '无法播放：该歌曲暂无版权',
          statusCode: 3,
        );
}

class ServerErrorException extends ApiException {
  const ServerErrorException(super.message, {super.statusCode});
}

class ParsingErrorException extends ApiException {
  const ParsingErrorException(super.message, {super.statusCode});
}

class NetworkErrorException extends ApiException {
  const NetworkErrorException(super.message, {super.statusCode});

  factory NetworkErrorException.fromDio(DioException e) {
    final msg = switch (e.type) {
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.receiveTimeout => '响应超时',
      DioExceptionType.connectionError => '网络连接失败',
      _ => '网络错误: ${e.message}',
    };
    return NetworkErrorException(msg);
  }
}
