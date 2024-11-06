import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:instagram/data/post.dart';
import 'package:instagram/pages/login_page.dart';
import 'package:instagram/pages/write_page.dart';
import 'package:instagram/widgets/post_widget.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Post> _posts = [];
  List<String?> _activeUsers = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPosts();
      _loadActiveUsers();
    // Remote Config로 부터 공지사항이 있는지 체크를 하고 만약 있으면 팝업 노출
      _loadNotice();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 글쓰기 버튼
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF1F2F3),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: SafeArea(
          bottom: false,
          child: CupertinoScrollbar(
            child: ListView(
              children: [
                // 인스타그램에 접속한 유저 목록
                _buildActiveUsers(),

                // 인스타그램 피드 카드
                for (final item in _posts)
                  PostWidget(
                    item: item,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveUsers() {
    return Container(
      height: 100,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        children: [
          for (final userName in _activeUsers) _buildActiveUserCircle(userName),
        ],
      ),
    );
  }

  Widget _buildActiveUserCircle(String? userName) {
    if (userName == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: 72,
      height: 72,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Colors.yellow,
            Colors.orangeAccent,
            Colors.redAccent,
            Colors.purpleAccent,
          ],
          stops: [0.1, 0.4, 0.6, 0.9],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF1F2F3),
        ),
        child: Container(
          padding: EdgeInsets.all(10),
          alignment: Alignment.center,
          child: Text(
            userName,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    final isWriteButtonRed = FirebaseRemoteConfig.instance.getBool('write_button_red');

    return AppBar(
      backgroundColor: const Color(0xFFF1F2F3),
      title: Image.asset(
        'assets/logo2.png',
        width: 120,
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Icons.add_box_outlined,
            color: isWriteButtonRed ? Colors.red : Colors.black,
          ),
          onPressed: () async {
            // 글쓰기 페이지로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) {
                  return WritePage();
                },
              ),
            );
            _loadPosts();
          },
        ),
        Container(
          margin: EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: Colors.black,
            ),
            onPressed: () async {
              // 로그아웃 처리
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) {
                    return LoginPage();
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Future<void> _loadPosts() async {
    // FirebaseFirestore로부터 데이터를 받아옵니다.
    final snapshot = await FirebaseFirestore.instance.collection("posts").orderBy("createdAt", descending: true).get();
    final documents = snapshot.docs;

    // FirebaseFirestore로부터 받아온 데이터를 Post 객체로 변환합니다.
    List<Post> posts = [];

    for (final doc in documents) {
      final data = doc.data();
      final uid = data['uid'];
      final username = data['username'];
      final description = data['description'];
      final imageUrl = data['imageUrl'];
      final createdAt = data['createdAt'];
      posts.add(
        Post(
          uid: uid,
          username: username,
          description: description,
          imageUrl: imageUrl,
          createdAt: createdAt,
        ),
      );
    }

    // Post 객체를 이용하여 화면을 다시 그립니다.
    setState(() {
      _posts = posts;
    });
  }

  // 활동 중인 사용자 목록을 받아옵니다.
  void _loadActiveUsers() {
    FirebaseDatabase.instance.ref().child('active_users').onValue.listen(
      (event) {
        setState(() {
          _activeUsers = List<String?>.from(
            event.snapshot.value as List<dynamic>,
          );
        });
      },
    );
  }

  // 공지사항을 RemoteConfig로부터 받아와서 보여줍니다.
  Future<void> _loadNotice() async {
    String notice = "";    
    // TODO : RemoteConfig에서 notice 값을 받아와서 다이얼로그로 보여줍니다.
    notice = FirebaseRemoteConfig.instance.getString('notice');

    // TODO : notice 값이 비어있으면 아래 코드를 실행하지 않고 바로 종료
    if (notice.isEmpty) return;

    // TODO : notice 값이 비어있지 않으면 아래 코드를 실행
    // if (notice.isNotEmpty) -> 가독성 안좋음
    showDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('공지사항'),
          content: Container(
            margin: const EdgeInsets.only(top: 10),
            child: Text(notice),
          ),
          actions: [
            CupertinoButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
