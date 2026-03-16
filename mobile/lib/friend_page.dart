import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/friend_service.dart';
// N'oublie pas cet import pour que la page de création de groupe soit reconnue
import 'chat/create_group_page.dart'; 
import 'chat/chat_list_page.dart';

class FriendPage extends StatefulWidget {
  const FriendPage({super.key});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final FriendService _friendService = FriendService();
  
  List<dynamic> _friends = [];
  List<dynamic> _pendingRequests = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData(); 
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final results = await Future.wait([
      _friendService.getFriends(),
      _friendService.getPendingRequests(),
    ]);
    
    if (mounted) {
      setState(() {
        _friends = results[0];
        _pendingRequests = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(int requestId) async {
    final success = await _friendService.acceptRequest(requestId);
    if (success) {
      _loadData(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande acceptée !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showAddFriendDialog() {
    final TextEditingController usernameController = TextEditingController();
    final scaffoldContext = context;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un ami'),
        content: TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: "Pseudo de l'utilisateur",
            hintText: 'Ex: johndoe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final username = usernameController.text.trim(); 
              if (username.isNotEmpty) {
                Navigator.pop(dialogContext); 
                final success = await _friendService.sendRequest(username);
                if (mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Text(success 
                        ? 'Demande envoyée à $username !' 
                        : 'Erreur : Utilisateur introuvable ou demande existante.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes Amis'), 
          actions: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _showAddFriendDialog,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mes Amis'),
              Tab(text: 'Demandes'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // --- ONGLET 1 : LA LISTE D'AMIS ---
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: _friends.isEmpty
                        ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Tu n'as pas encore d'amis.")))])
                        : ListView.builder(
                            itemCount: _friends.length,
                            itemBuilder: (context, index) {
                              final friend = _friends[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(friend['username'].toString().substring(0, 1).toUpperCase()),
                                ),
                                title: Text(friend['username']),
                                subtitle: Text(friend['email']),
                              );
                            },
                          ),
                  ),

                  // --- ONGLET 2 : LES DEMANDES EN ATTENTE ---
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: _pendingRequests.isEmpty
                        ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Aucune demande en attente.")))])
                        : ListView.builder(
                            itemCount: _pendingRequests.length,
                            itemBuilder: (context, index) {
                              final request = _pendingRequests[index];
                              final requester = request['requester'];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Text(requester['username'].toString().substring(0, 1).toUpperCase()),
                                ),
                                title: Text(requester['username']),
                                subtitle: const Text('Veut être ton ami(e)'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                  onPressed: () => _acceptRequest(request['requestId']),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateGroupPage()),
            );
          },
          label: const Text('Groupe'),
          icon: const Icon(Icons.group_add),
        ),
      ),
    );
  }
}