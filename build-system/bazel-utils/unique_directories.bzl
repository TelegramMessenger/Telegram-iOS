
def unique_directories(paths):
    result = []
    for path in paths:
        index = path.rfind("/")
        if index != -1:
            directory = path[:index]
            if not directory in result:
                result.append(directory)
    return result
