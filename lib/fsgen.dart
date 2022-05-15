import 'package:dartdoc/dartdoc.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';

class Dependency {
  final Uri libraryUri;
  final String libraryName;
  final String libraryVersion;

  Dependency(this.libraryUri, this.libraryName, this.libraryVersion);

  @override
  bool operator ==(Object other) =>
      other is Dependency &&
      (libraryUri == other.libraryUri &&
          libraryName == other.libraryName &&
          libraryVersion == other.libraryVersion);

  @override
  int get hashCode => Object.hash(libraryUri, libraryName, libraryVersion);

  @override
  String toString() {
    return 'Dependency{libraryUri: $libraryUri, libraryName: $libraryName, libraryVersion: $libraryVersion}';
  }
}

class FsGenerator implements Generator {
  Dependency? dependency(
      LibraryElement? elementType, PackageGraph packageGraph) {
    if (elementType == null) return null;
    final metadata = packageGraph.packageMetaProvider
        .fromElement(elementType, packageGraph.config.sdkDir);
    return Dependency(elementType.source.uri, metadata!.name, metadata.version);
  }

  String extractNamedParams(Iterable<ParameterElement> parameters) {
    var positionalUntil = -1;
    for (final p in parameters) {
      positionalUntil += 1;
      if (p.isNamed) {
        break;
      }
    }
    return positionalUntil != -1 && positionalUntil != parameters.length - 1? '[<NamedParams${positionalUntil != 0 ? '(fromIndex=$positionalUntil)' : ''}>] ' : '';
  }
  String renderParams(Iterable<ParameterElement> parameters) {
    return '(${parameters.isEmpty ? '' : parameters.map((e) => '${e.isRequiredNamed || e.isRequiredPositional ? '' : '?'}${e.name} : ${e is TypeParameterElementType ? "'":''}${e.type.element?.name ?? e.type.alias?.element.name ?? e.type.getDisplayString(withNullability: true)}').reduce((value, element) => '$value, $element')})';
  }

  String renderGenericArgs(Iterable<Element> genericParams) => genericParams
          .isEmpty
      ? ''
      : '<${genericParams.map((e) => "${e.kind == ElementKind.TYPE_PARAMETER ? "'":''}${e.name}").reduce((value, element) => '$value, $element')}>';

  @override
  Future<void> generate(PackageGraph packageGraph, FileWriter writer) async {
    for (final package in packageGraph.packages) {
      var buffer = StringBuffer();

      for (final lib in package.libraries) {
        if (!lib.isPublic) continue;
        buffer.writeln('module rec ``${lib.name}``=');
        final currentLibUri = lib.element.source.uri;
        final dependencies = Set<Dependency>.identity();
        for (final libEl in lib.element.importedLibraries) {
          if (libEl.isPrivate) continue;
          final dep = dependency(libEl, packageGraph);
          if (dep != null && dep.libraryUri != currentLibUri) {
            dependencies.add(dep);
          }
        }
        for (final clazz in lib.classes) {
          if (!clazz.isCanonical) continue;
          final genericParams = clazz.typeParameters;
          final renderedClassGenerics =
              renderGenericArgs(genericParams.map((e) => e.element!));
          var headerPrinted = false;
          var moreThanHeader = false;
          var defaultConstructor = clazz.unnamedConstructor;
          final superClazz = (clazz.supertype?.isPublic ?? false) ? clazz.supertype : null;
          final superGenerics = renderGenericArgs(
              superClazz?.typeArguments.where((e) => e.type.element != null)
                  .map((e) => e.type.element!) ?? []);
          buffer.writeln('  [<ImportMember("$currentLibUri")>');
          if (defaultConstructor != null) {
            headerPrinted = true;
            final renderedParams = renderParams(defaultConstructor.parameters.map((e) => e.element!));
            buffer.writeln(
                '  type ${clazz.name}$renderedClassGenerics ${extractNamedParams(defaultConstructor.parameters.map((e) => e.element!))} $renderedParams =');
          }
          if (superClazz != null) {
            moreThanHeader = true;
            final args = ((defaultConstructor?.element as ConstructorElementImpl?)?.superConstructor?.parameters.length ?? 0);
            buffer.writeln('    inherit ${superClazz.name}$superGenerics(${args == 0 ? '' : List.generate(args, (_) => 'jsNative')
                .reduce((value, element) => '$value, $element')})');
          }

          if (!headerPrinted) {
            headerPrinted = true;
            buffer.writeln('  type ${clazz.name}$renderedClassGenerics =');
          }
          for (final constructor in clazz.constructors
              .where((element) => !element.isUnnamedConstructor)) {
            if (!constructor.isCanonical) continue;
            final renderedParams = renderParams(constructor.parameters.map((e) => e.element!));
            moreThanHeader = true;
            final treated = constructor.name.substring(clazz.name.length + 1);
            buffer.writeln(
                '    ${extractNamedParams(constructor.parameters.map((e) => e.element!))}${treated != 'new' ? 'static member' : ''} $treated$renderedParams : ${clazz.name}$renderedClassGenerics = jsNative');
            //print('SDK? ${lib.isInSdk} - $package - ${package.packageMeta.version} - ${lib.element.source.uri} - $lib - $clazz - ${clazz.supertype ?? 'No super'} - $constructor');
          }

          if (!moreThanHeader) {
            buffer.writeln('    class end');
          }
          buffer.writeln();
        }

        writer.write('${lib.hashCode}.fs', buffer.toString());

        print('$lib dependencies:');
        for (final d in dependencies) {
          print(d);
        }
      }
    }
  }
}
