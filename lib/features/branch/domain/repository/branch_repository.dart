import '../entities/branch_entity.dart';

abstract class BranchRepository {
  Future<List<BranchEntity>> listBranches();
}

