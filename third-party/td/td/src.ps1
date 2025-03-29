git ls-tree -r HEAD --name-only benchmark example memprof td tdactor tddb tde2e tdnet tdtl tdutils test | Select-String "\.cpp$|\.h$|\.hpp$"
