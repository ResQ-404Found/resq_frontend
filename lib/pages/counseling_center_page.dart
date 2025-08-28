import 'package:flutter/material.dart';
import 'counseling_chatbot_page.dart'; // 파란 헤더(심리)
import 'chatbot_page.dart';            // 빨간 헤더(재난)
import 'app_bottom_nav.dart';

class CounselingCenterPage extends StatelessWidget {
  const CounselingCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _centerAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hero(),
              const SizedBox(height: 12),
              _titleBlock(),
              const SizedBox(height: 12),
              _menuCard(
                context,
                title: '재난 대응 상담',
                subtitle: '지진, 화재, 침수 등\n재난 상황별 대응 방법',
                iconGradient: const LinearGradient(
                  colors: [Color(0xFFFF7043), Color(0xFFEF5350)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                icon: Icons.shield_outlined,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ChatbotPage()),
                ),
              ),
              const SizedBox(height: 12),
              _menuCard(
                context,
                title: '심리 지원 상담',
                subtitle: '스트레스 관리 및\n심리적 지원 안내',
                iconGradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF26C6DA)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                icon: Icons.favorite_outline,
                onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CounselingChatbotPage()),
                ),
              ),
              const SizedBox(height: 20),


            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  PreferredSizeWidget _centerAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI 상담 센터',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2F2F2F))),
                      SizedBox(height: 2),
                      Text('24시간 언제나 도움을 드립니다',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF8C8C8C))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF7C4DFF), Color(0xFFFF6E6E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: Color(0x337C4DFF), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: const Icon(Icons.assistant_photo, color: Colors.white, size: 34),
      ),
    );
  }

  Widget _titleBlock() {
    return Column(
      children: const [
        Text('안전 지키미 AI',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2C2C2C))),
        SizedBox(height: 8),
        Text(
          '재난 상황과 상담이 필요할 때\n전문적인 도움을 받으세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, height: 1.4, color: Color(0xFF737373)),
        ),
      ],
    );
  }

  Widget _menuCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required LinearGradient iconGradient,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: iconGradient,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF2D2D2D))),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF8A8A8A))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB5B5B5)),
          ],
        ),
      ),
    );
  }
  }

