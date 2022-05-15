import 'package:dartdoc/options.dart';
import 'package:fsgen/fsgen.dart' as fsgen;
import 'package:dartdoc/dartdoc.dart';

Future<void> main(List<String> arguments) async {
  var config = parseOptions(pubPackageMetaProvider, arguments);
  if (config == null) {
    return;
  }
  final packageConfigProvider = PhysicalPackageConfigProvider();
  final packageBuilder =
  PubPackageBuilder(config, pubPackageMetaProvider, packageConfigProvider);
  final dartdoc = Dartdoc.withEmptyGenerator(config, packageBuilder);
  dartdoc.generator = fsgen.FsGenerator();
  dartdoc.executeGuarded();
}