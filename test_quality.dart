import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://171.80.2.129:42980',
    connectTimeout: const Duration(seconds: 10),
  ));

  print('=== Step 1: 发送验证码 ===');
  final phone = '17820201177';
  try {
    final sendResp = await dio.get('/captcha/sent', queryParameters: {'mobile': phone});
    print('验证码发送结果: ${sendResp.data}');
  } catch (e) {
    print('发送失败: $e');
  }

  print('\n请输入验证码: ');
  final code = stdin.readLineSync();
  if (code == null || code.isEmpty) {
    print('未输入验证码');
    return;
  }

  print('\n=== Step 2: 登录 ===');
  try {
    final loginResp = await dio.get('/login/cellphone', queryParameters: {
      'mobile': phone,
      'code': code
    });
    print('登录结果: ${loginResp.data}');

    if (loginResp.data['status'] != 1) {
      print('登录失败');
      return;
    }

    final token = loginResp.data['token'] ?? '';
    final userId = loginResp.data['userid'] ?? '';
    final cookie = 'token=$token;userid=$userId';
    print('Cookie: $cookie');

    print('\n=== Step 3: 搜索歌曲获取 hash ===');
    final searchResp = await dio.get('/search', queryParameters: {
      'keywords': '周杰伦',
      'cookie': cookie
    });
    final songs = searchResp.data['data']?['info'] as List? ?? [];
    if (songs.isEmpty) {
      print('未找到歌曲');
      return;
    }
    final song = songs[0];
    final hash = song['hash'] ?? '';
    print('歌曲: ${song['songname']}, hash: $hash');

    print('\n=== Step 4: 测试音质切换API ===');

    print('\n--- Basic call ---');
    final r1 = await dio.get('/song/url', queryParameters: {'hash': hash, 'cookie': cookie});
    print('Response: ${r1.data}');

    print('\n--- With br=128000 ---');
    final r2 = await dio.get('/song/url', queryParameters: {'hash': hash, 'br': 128000, 'cookie': cookie});
    print('Response: ${r2.data}');

    print('\n--- With br=320000 ---');
    final r3 = await dio.get('/song/url', queryParameters: {'hash': hash, 'br': 320000, 'cookie': cookie});
    print('Response: ${r3.data}');
  } catch (e) {
    print('请求失败: $e');
  }
}