from termcolor import colored
import platform

class Color:
    def mood(self, currentmood):
        if platform.system is "Windows":
            return "*"
        else:
            if currentmood is "happy":
                return colored("*", "green")
            elif currentmood is "neutral":
                return colored("*", "yellow")
            elif currentmood is "sad":
                return colored("*", "red")
            else:
                return "*"
