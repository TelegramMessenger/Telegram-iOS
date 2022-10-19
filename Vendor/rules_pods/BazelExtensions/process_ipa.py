import os
import sys

# Move directories matching the naming convention in Pods
# All of our bundles conform to the naming convention
# PackageName_Bundle_BundleName
# Move them to BundleName.bundle
bundle_token = "_Bundle_"
def main(argv):
    for dirname, dirnames, filenames in os.walk(argv[1]):
        split_dir = dirname.split('/')
        if bundle_token in split_dir[len(split_dir) - 1]:
            bundle_namespace = dirname.split(bundle_token)[1]
            base_dir = "/".join(split_dir[0: len(split_dir) - 1])
            new_path = base_dir + "/" + bundle_namespace
            os.system("mv " + dirname + " " + new_path)

if __name__ == '__main__':
    sys.exit(main(sys.argv))
