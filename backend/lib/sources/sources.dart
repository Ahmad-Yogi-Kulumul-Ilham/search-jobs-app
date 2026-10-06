import 'job_source.dart';
import 'jobicy_source.dart';
import 'remote_ok_source.dart';
import 'remotive_source.dart';
import 'we_work_remotely_source.dart';

export 'job_source.dart';

/// Every source the app reads, in the order shown in the source filter.
const List<JobSource> allSources = [
  RemoteOkSource(),
  JobicySource(),
  WeWorkRemotelySource(),
  RemotiveSource(),
];
